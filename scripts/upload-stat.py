#! /usr/bin/env python3
#
# Parse the stat.txt file from lang-stat and upload to the metrics collection endpoint

import sys
import urllib.request

HOST = "https://dashboard.semgrep.dev"


def parse_stat_file(in_file):
    stats = []
    with open(in_file) as f:
        lines = [line.rstrip("\n") for line in f]

    lang = None
    line_count = None
    parse_success = None
    for line in lines:
        if line.startswith("Language: "):
            lang = line.replace("Language: ", "")
            continue
        elif line.startswith("Line count: "):
            line_count = line.replace("Line count: ", "")
            continue
        elif line.startswith("Line coverage: "):
            parse_success = line.replace("Line coverage: ", "").replace("%", "")
            continue
        else:
            if (
                lang is not None
                and line_count is not None
                and parse_success is not None
            ):
                stats.append(
                    {
                        "lang": lang,
                        "line_count": line_count,
                        "parse_success": parse_success,
                    }
                )
            lang = None
            line_count = None
            parse_success = None
    return stats


def upload_stats(stats):
    for stat in stats:
        url = f"{HOST}/api/metric/semgrep.core.{stat['lang']}.parse.pct"
        r = urllib.request.urlopen(url=url, data=stat["parse_success"].encode("ascii"))
        print(r.read().decode())
        url = f"{HOST}/api/metric/semgrep.core.{stat['lang']}.parse-coverage-lines.num"
        r = urllib.request.urlopen(url=url, data=stat["line_count"].encode("ascii"))
        print(r.read().decode())


if __name__ == "__main__":
    if len(sys.argv) > 1:
        in_file = sys.argv[1]
        stats = parse_stat_file(in_file)
        upload_stats(stats)
    else:
        print("please give a path to stat.txt as the first argument")
        sys.exit(1)
