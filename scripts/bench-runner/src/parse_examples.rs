//! Parallel replacement for the `parse-examples` bash script.
//!
//! Runs OCaml parsers on test files in test/ok and test/xfail directories,
//! executing all parses in parallel with progress reporting.
//!
//! Usage: parse-examples LANG

use indicatif::{ProgressBar, ProgressStyle};
use rayon::prelude::*;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicU32, Ordering};
use walkdir::WalkDir;

#[derive(Clone, Copy, PartialEq)]
enum Expect {
    Ok,
    Xfail,
}

#[derive(Clone, Copy, PartialEq)]
enum Outcome {
    Pass,
    Fail,
    Xpass,
    Xfail,
}

impl Outcome {
    fn label(self) -> &'static str {
        match self {
            Outcome::Pass => "PASS",
            Outcome::Fail => "FAIL",
            Outcome::Xpass => "XPASS",
            Outcome::Xfail => "XFAIL",
        }
    }

    fn is_unexpected(self) -> bool {
        matches!(self, Outcome::Fail | Outcome::Xpass)
    }
}

struct TestJob {
    src: PathBuf,
    expect: Expect,
    /// Path relative to test/ok or test/xfail, used for output location.
    common_path: String,
}

struct TestResult {
    job: TestJob,
    outcome: Outcome,
}

fn discover_tests(expect: Expect) -> Vec<TestJob> {
    let dir_name = match expect {
        Expect::Ok => "ok",
        Expect::Xfail => "xfail",
    };
    let expect_dir = PathBuf::from("test").join(dir_name);
    if !expect_dir.is_dir() {
        return Vec::new();
    }

    let prefix = format!("test/{dir_name}/");
    WalkDir::new(&expect_dir)
        .into_iter()
        .filter_map(Result::ok)
        .filter(|e| e.file_type().is_file())
        .map(|e| {
            let src = e.into_path();
            let common_path = src
                .to_string_lossy()
                .strip_prefix(&prefix)
                .unwrap_or(&src.to_string_lossy())
                .to_string();
            TestJob {
                src,
                expect,
                common_path,
            }
        })
        .collect()
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 2 {
        eprintln!("Usage: parse-examples LANG");
        std::process::exit(1);
    }
    let lang = &args[1];
    let parser = format!("./parse-{lang}");

    if !Path::new(&parser).exists() {
        eprintln!("Error: parser not found at {parser}");
        std::process::exit(1);
    }

    let outdir = PathBuf::from("test.out");
    let _ = fs::remove_dir_all(&outdir);
    fs::create_dir_all(&outdir).unwrap();

    // Discover all test files.
    let mut jobs = discover_tests(Expect::Ok);
    jobs.extend(discover_tests(Expect::Xfail));

    if jobs.is_empty() {
        eprintln!("No test files found in test/ok or test/xfail");
        std::process::exit(0);
    }

    // Create output directories (must happen before parallel parsing).
    for job in &jobs {
        let dir_name = match job.expect {
            Expect::Ok => "ok",
            Expect::Xfail => "xfail",
        };
        let cst = outdir.join(dir_name).join(format!("{}.cst", job.common_path));
        if let Some(parent) = cst.parent() {
            fs::create_dir_all(parent).unwrap();
        }
    }

    let pb = ProgressBar::new(jobs.len() as u64);
    pb.set_style(
        ProgressStyle::with_template(
            "{prefix:.bold} [{bar:30.green/dim}] {pos}/{len} tests  {msg}",
        )
        .unwrap()
        .progress_chars("=> "),
    );
    pb.set_prefix("Testing");

    let fail_count = AtomicU32::new(0);
    let pass_count = AtomicU32::new(0);
    let xfail_count = AtomicU32::new(0);
    let xpass_count = AtomicU32::new(0);

    let results: Vec<TestResult> = jobs
        .into_par_iter()
        .map(|job| {
            let dir_name = match job.expect {
                Expect::Ok => "ok",
                Expect::Xfail => "xfail",
            };
            let cst_path = outdir.join(dir_name).join(format!("{}.cst", job.common_path));

            let output = Command::new(&parser)
                .arg(&job.src)
                .stdout(Stdio::piped())
                .stderr(Stdio::piped())
                .output();

            let success = output.as_ref().map(|o| o.status.success()).unwrap_or(false);

            // Write CST output.
            if let Ok(ref out) = output {
                let mut combined = out.stdout.clone();
                combined.extend_from_slice(&out.stderr);
                let _ = fs::write(&cst_path, &combined);
            }

            let outcome = match (job.expect, success) {
                (Expect::Ok, true) => Outcome::Pass,
                (Expect::Ok, false) => Outcome::Fail,
                (Expect::Xfail, true) => Outcome::Xpass,
                (Expect::Xfail, false) => Outcome::Xfail,
            };

            match outcome {
                Outcome::Pass => pass_count.fetch_add(1, Ordering::Relaxed),
                Outcome::Fail => fail_count.fetch_add(1, Ordering::Relaxed),
                Outcome::Xpass => xpass_count.fetch_add(1, Ordering::Relaxed),
                Outcome::Xfail => xfail_count.fetch_add(1, Ordering::Relaxed),
            };

            let label = outcome.label();
            let src_display = job.src.display();
            if outcome.is_unexpected() {
                pb.println(format!("  {label}: {src_display}"));
            }

            pb.inc(1);

            TestResult {
                job,
                outcome,
            }
        })
        .collect();

    pb.finish_and_clear();

    // Print all results in a stable order (sorted by source path).
    let mut sorted_results = results;
    sorted_results.sort_by(|a, b| a.job.src.cmp(&b.job.src));

    for r in &sorted_results {
        println!("{}: {}", r.outcome.label(), r.job.src.display());
    }

    // Write fail/xpass lists.
    let fail_list: Vec<&str> = sorted_results
        .iter()
        .filter(|r| r.outcome == Outcome::Fail)
        .map(|r| r.job.common_path.as_str())
        .collect();
    let xpass_list: Vec<&str> = sorted_results
        .iter()
        .filter(|r| r.outcome == Outcome::Xpass)
        .map(|r| r.job.common_path.as_str())
        .collect();

    if !fail_list.is_empty() {
        let path = outdir.join("fail.list");
        fs::write(&path, fail_list.join("\n") + "\n").unwrap();
    }
    if !xpass_list.is_empty() {
        let path = outdir.join("xpass.list");
        fs::write(&path, xpass_list.join("\n") + "\n").unwrap();
    }

    let pass = pass_count.load(Ordering::Relaxed);
    let fail = fail_count.load(Ordering::Relaxed);
    let xfail = xfail_count.load(Ordering::Relaxed);
    let xpass = xpass_count.load(Ordering::Relaxed);
    let expected = pass + xfail;
    let unexpected = fail + xpass;

    println!();
    println!("expected results: {expected} (pass: {pass}, xfail: {xfail})");
    println!("unexpected results: {unexpected} (fail: {fail}, xpass: {xpass})");

    if unexpected != 0 {
        eprintln!();
        eprintln!("*** Some {lang} parsing tests didn't meet the expectations.");
        eprintln!();
        eprintln!("The lists of failing targets are here:");
        eprintln!("  - 'test.out/fail.list': parsing was expected to succeed but failed");
        eprintln!("  - 'test.out/xpass.list': parsing was expected to fail but succeeded");
        eprintln!();
        eprintln!("The output of the parser for each file was put in 'test.out/'.");
        eprintln!(
            "Alternatively, you can run the parser './parse-{lang}' on an arbitrary"
        );
        eprintln!("file to see what the CST looks like.");
        std::process::exit(1);
    }
}
