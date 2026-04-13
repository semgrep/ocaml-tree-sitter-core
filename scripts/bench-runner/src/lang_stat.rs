//! Parallel replacement for the `lang-stat` bash script.
//!
//! Clones repos in parallel, finds matching files, then parses them all in
//! parallel -- collecting per-project and global statistics with progress
//! reporting.
//!
//! Usage: lang-stat LANG PROJECTS_FILE EXTENSIONS_FILE

use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use rayon::prelude::*;
use std::collections::BTreeMap;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Mutex;
use walkdir::WalkDir;

// ── Types ───────────────────────────────────────────────────────────────────

/// Result of parsing a single file.
struct FileResult {
    /// Project this file belongs to.
    project: String,
    /// The file that was parsed (workspace-relative path for stat.fail).
    file_path: String,
    /// Exit status of the parser.
    status: i32,
    /// Total line count reported by the parser.
    total_lines: u64,
    /// Error line count reported by the parser.
    error_lines: u64,
    /// Error count reported by the parser.
    error_count: u64,
    /// Path to per-file json error log (if any errors).
    json_err_path: Option<PathBuf>,
    /// Stderr captured from the parser.
    stderr: String,
}

/// Accumulated statistics for one project.
#[derive(Default)]
struct ProjectStats {
    url: String,
    num_files: u64,
    failed_files: u64,
    lines: u64,
    error_lines: u64,
    ext_errors: u64,
    int_errors: u64,
    other_errors: u64,
}

// ── Helpers ─────────────────────────────────────────────────────────────────

fn read_nonempty_lines(path: &Path) -> Vec<String> {
    let content = fs::read_to_string(path).unwrap_or_else(|e| {
        eprintln!("Error: cannot read {}: {e}", path.display());
        std::process::exit(1);
    });
    content
        .lines()
        .map(str::trim)
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
        .map(String::from)
        .collect()
}

fn repo_name(url: &str) -> String {
    let base = url.rsplit('/').next().unwrap_or(url);
    base.strip_suffix(".git").unwrap_or(base).to_string()
}

/// Find files under `root` whose name ends with one of `extensions`.
fn find_matching_files(root: &Path, extensions: &[String]) -> Vec<PathBuf> {
    let mut files = Vec::new();
    for entry in WalkDir::new(root).into_iter().filter_map(Result::ok) {
        if !entry.file_type().is_file() {
            continue;
        }
        let name = entry.file_name().to_string_lossy();
        // Match: file must contain a dot before the extension (not a dotfile).
        for ext in extensions {
            if name.ends_with(ext.as_str()) {
                // Ensure there's a non-dot character before the extension.
                let prefix = &name[..name.len() - ext.len()];
                if !prefix.is_empty() && !prefix.ends_with('.') {
                    files.push(entry.into_path());
                    break;
                }
            }
        }
    }
    files
}

// ── Main ────────────────────────────────────────────────────────────────────

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 4 {
        eprintln!("Usage: lang-stat LANG PROJECTS_FILE EXTENSIONS_FILE");
        std::process::exit(1);
    }
    let lang = &args[1];
    let projects_file = Path::new(&args[2]);
    let extensions_file = Path::new(&args[3]);

    let urls = read_nonempty_lines(projects_file);
    let extensions = read_nonempty_lines(extensions_file);
    if extensions.is_empty() {
        eprintln!("Error: no extensions found in {}", extensions_file.display());
        std::process::exit(1);
    }

    // Locate parser binary.
    let parser = std::env::current_dir()
        .unwrap()
        .join(format!("ocaml-src/_build/install/default/bin/parse-{lang}"));
    if !parser.is_file() {
        eprintln!("Error: missing parser '{}'", parser.display());
        std::process::exit(1);
    }

    let tmp = PathBuf::from("stat.tmp");
    let stat_dir = std::env::current_dir().unwrap().join("stat");

    // Wipe and recreate output dir.
    let _ = fs::remove_dir_all(&stat_dir);
    fs::create_dir_all(&stat_dir).unwrap();
    fs::create_dir_all(&tmp).unwrap();

    // ── Phase 1: Clone repos in parallel ────────────────────────────────

    let mp = MultiProgress::new();
    let clone_style = ProgressStyle::with_template(
        "{prefix:.bold} [{bar:30.cyan/dim}] {pos}/{len} repos cloned",
    )
    .unwrap()
    .progress_chars("=> ");

    let clone_pb = mp.add(ProgressBar::new(urls.len() as u64));
    clone_pb.set_style(clone_style);
    clone_pb.set_prefix("Cloning");

    let clone_errors: Mutex<Vec<String>> = Mutex::new(Vec::new());

    urls.par_iter().for_each(|url| {
        let name = repo_name(url);
        let proj_dir = tmp.join(&name);
        fs::create_dir_all(&proj_dir).unwrap();
        let repo_dir = proj_dir.join(&name);

        if repo_dir.is_dir() {
            // Verify origin matches.
            let output = Command::new("git")
                .args(["-C", &repo_dir.to_string_lossy(), "remote", "get-url", "origin"])
                .output();
            if let Ok(out) = output {
                let origin = String::from_utf8_lossy(&out.stdout).trim().to_string();
                if origin != *url {
                    clone_errors.lock().unwrap().push(format!(
                        "Wrong remote URL in cloned repo '{name}': found {origin}, expected {url}"
                    ));
                } else {
                    clone_pb.println(format!("  [cached] {name}"));
                }
            }
        } else {
            let result = Command::new("git")
                .args(["clone", "--depth", "1", url, &repo_dir.to_string_lossy()])
                .stdout(Stdio::null())
                .stderr(Stdio::piped())
                .status();
            match result {
                Ok(s) if s.success() => {
                    clone_pb.println(format!("  [cloned] {name}"));
                }
                Ok(s) => {
                    clone_errors.lock().unwrap().push(format!(
                        "git clone failed for {url} (exit {})",
                        s.code().unwrap_or(-1)
                    ));
                }
                Err(e) => {
                    clone_errors
                        .lock()
                        .unwrap()
                        .push(format!("git clone failed for {url}: {e}"));
                }
            }
        }
        clone_pb.inc(1);
    });
    clone_pb.finish_with_message("done");

    let errors = clone_errors.into_inner().unwrap();
    if !errors.is_empty() {
        for e in &errors {
            eprintln!("Error: {e}");
        }
        std::process::exit(1);
    }

    // ── Phase 2: Discover files ─────────────────────────────────────────

    // Collect (project_name, file_path) pairs.
    struct ParseJob {
        project: String,
        file: PathBuf,
    }

    let mut jobs: Vec<ParseJob> = Vec::new();
    let mut project_urls: BTreeMap<String, String> = BTreeMap::new();

    for url in &urls {
        let name = repo_name(url);
        let repo_dir = tmp.join(&name).join(&name);
        let files = find_matching_files(&repo_dir, &extensions);
        for f in files {
            jobs.push(ParseJob {
                project: name.clone(),
                file: f,
            });
        }
        project_urls.insert(name, url.clone());
    }

    eprintln!(
        "Found {} files across {} projects",
        jobs.len(),
        project_urls.len()
    );

    // ── Phase 3: Parse all files in parallel ────────────────────────────

    let parse_style = ProgressStyle::with_template(
        "{prefix:.bold} [{bar:30.green/dim}] {pos}/{len} files parsed  {msg}",
    )
    .unwrap()
    .progress_chars("=> ");

    let parse_pb = mp.add(ProgressBar::new(jobs.len() as u64));
    parse_pb.set_style(parse_style);
    parse_pb.set_prefix("Parsing");

    let error_file_counter = AtomicUsize::new(0);

    // Each job gets its own stat file and json err log to avoid races.
    let results: Vec<FileResult> = jobs
        .par_iter()
        .enumerate()
        .map(|(i, job)| {
            let proj_workspace = tmp.join(&job.project);
            let stat_file = proj_workspace.join(format!("stat-{i}.txt"));
            let json_err_file = proj_workspace.join(format!("err-{i}.json"));

            let output = Command::new(&parser)
                .arg(&job.file)
                .arg("--txt-stat")
                .arg(&stat_file)
                .arg("--json-error-log")
                .arg(&json_err_file)
                .stdout(Stdio::null())
                .stderr(Stdio::piped())
                .output();

            let (status, stderr) = match output {
                Ok(out) => (
                    out.status.code().unwrap_or(1),
                    String::from_utf8_lossy(&out.stderr).to_string(),
                ),
                Err(e) => {
                    parse_pb.println(format!("  [error] {}: {e}", job.file.display()));
                    (-1, e.to_string())
                }
            };

            // Read stat file.
            let (total_lines, error_lines, error_count) = fs::read_to_string(&stat_file)
                .ok()
                .and_then(|s| {
                    let parts: Vec<&str> = s.trim().split_whitespace().collect();
                    if parts.len() >= 3 {
                        Some((
                            parts[0].parse::<u64>().unwrap_or(0),
                            parts[1].parse::<u64>().unwrap_or(0),
                            parts[2].parse::<u64>().unwrap_or(0),
                        ))
                    } else {
                        None
                    }
                })
                .unwrap_or((0, 0, 0));

            let json_err_path = if json_err_file.exists()
                && fs::metadata(&json_err_file)
                    .map(|m| m.len() > 0)
                    .unwrap_or(false)
            {
                Some(json_err_file)
            } else {
                let _ = fs::remove_file(&json_err_file);
                None
            };

            // Clean up stat file.
            let _ = fs::remove_file(&stat_file);

            if status != 0 {
                let n = error_file_counter.fetch_add(1, Ordering::Relaxed) + 1;
                parse_pb.set_message(format!("{n} errors"));
            }

            parse_pb.inc(1);

            FileResult {
                project: job.project.clone(),
                file_path: job.file.to_string_lossy().to_string(),
                status,
                total_lines,
                error_lines,
                error_count,
                json_err_path,
                stderr,
            }
        })
        .collect();

    parse_pb.finish_with_message("done");

    // ── Phase 4: Aggregate results ──────────────────────────────────────

    let mut by_project: BTreeMap<String, ProjectStats> = BTreeMap::new();
    for url in &urls {
        let name = repo_name(url);
        by_project.insert(
            name.clone(),
            ProjectStats {
                url: url.clone(),
                ..Default::default()
            },
        );
    }

    let mut global_line_count: u64 = 0;
    let mut global_error_line_count: u64 = 0;
    let mut failed_inputs: Vec<String> = Vec::new();

    // Merge JSON error logs.
    let global_json_err_path = stat_dir.join("parse-error.json");
    let mut json_err_out = fs::File::create(&global_json_err_path).unwrap();

    let mut global_stderr = String::new();

    for r in &results {
        let ps = by_project.get_mut(&r.project).unwrap();
        ps.num_files += 1;
        ps.lines += r.total_lines;
        global_line_count += r.total_lines;

        if r.status != 0 {
            ps.failed_files += r.error_count;
            ps.error_lines += r.error_lines;
            global_error_line_count += r.error_lines;

            match r.status {
                11 => ps.ext_errors += 1,
                12 => ps.int_errors += 1,
                _ => ps.other_errors += 1,
            }

            failed_inputs.push(r.file_path.clone());
        }

        if let Some(ref path) = r.json_err_path {
            if let Ok(data) = fs::read(path) {
                json_err_out.write_all(&data).unwrap();
            }
            let _ = fs::remove_file(path);
        }

        if !r.stderr.is_empty() {
            global_stderr.push_str(&r.stderr);
        }
    }
    drop(json_err_out);

    // Write CSV.
    let csv_path = stat_dir.join("stat.csv");
    {
        let mut csv = fs::File::create(&csv_path).unwrap();
        writeln!(
            csv,
            "Name,URL,Files,\"Failed files\",Lines,\"Failed lines\",\
             \"External errors\",\"Internal errors\",\"Other errors\""
        )
        .unwrap();
        for (name, ps) in &by_project {
            writeln!(
                csv,
                "{},{},{},{},{},{},{},{},{}",
                name,
                ps.url,
                ps.num_files,
                ps.failed_files,
                ps.lines,
                ps.error_lines,
                ps.ext_errors,
                ps.int_errors,
                ps.other_errors,
            )
            .unwrap();
        }
    }

    // Write failed inputs list.
    if !failed_inputs.is_empty() {
        let fail_path = stat_dir.join("stat.fail");
        fs::write(&fail_path, failed_inputs.join("\n") + "\n").unwrap();
    }

    // Write stderr log.
    if !global_stderr.is_empty() {
        let log_path = stat_dir.join("parse-error.log");
        fs::write(&log_path, &global_stderr).unwrap();
    }

    // Aggregate parse errors (call the existing Python script).
    // Locate it relative to the binary (which lives in scripts/bench-runner/target/release/).
    let agg_script = std::env::current_exe()
        .ok()
        .and_then(|exe| exe.parent().map(Path::to_path_buf))
        .map(|dir| {
            // Walk up from target/release/ to scripts/, then find the sibling script.
            let candidate = dir.join("../../aggregate-parse-errors");
            if candidate.exists() {
                return candidate;
            }
            // Fallback: try scripts/ relative to cwd.
            PathBuf::from("scripts/aggregate-parse-errors")
        })
        .unwrap_or_else(|| PathBuf::from("scripts/aggregate-parse-errors"));

    if agg_script.exists() {
        let agg_input = fs::File::open(&global_json_err_path).unwrap();
        let agg_output_path = stat_dir.join("aggregated-errors.csv");
        let agg_output = fs::File::create(&agg_output_path).unwrap();
        let status = Command::new(&agg_script)
            .stdin(agg_input)
            .stdout(agg_output)
            .status();
        if let Err(e) = status {
            eprintln!("Warning: failed to run aggregate-parse-errors: {e}");
        }
    } else {
        eprintln!(
            "Warning: aggregate-parse-errors not found at {}",
            agg_script.display()
        );
    }

    // Write and print summary.
    let line_coverage = if global_line_count > 0 {
        100.0 * (1.0 - global_error_line_count as f64 / global_line_count as f64)
    } else {
        100.0
    };

    let summary = format!(
        "Line count: {global_line_count}\nLine coverage: {line_coverage:.3}%\n"
    );
    let summary_path = stat_dir.join("summary.txt");
    fs::write(&summary_path, &summary).unwrap();
    print!("{summary}");
}
