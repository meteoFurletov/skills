#!/usr/bin/env python3
# sdlc-watch-version: 1
"""Stage 6 detector — watch the CI failure rate against a rolling baseline.

No model runs in the detection path. This pulls CI history with `gh`, computes a
daily failure rate, applies Western Electric rules over a rolling mean and
standard deviation, and matches the result against bands.yaml. Only once a band
is breached does it invoke Claude, and the only thing asked for is a diagnosis
written back as the next intent.md.

python3 stdlib only, plus `gh`. A missing dependency is a clear error, never a
silent pass.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import shutil
import statistics
import subprocess
import sys
from collections import defaultdict

SCRIPT_VERSION = 1
ACTIONS = ("none", "log", "diagnose", "propose_pr")


class WatchError(Exception):
    """Anything that stops the detector. Always surfaces as a clear message."""


# ---------------------------------------------------------------------------
# bands.yaml — a deliberately tiny reader, because stdlib has no YAML.
# ---------------------------------------------------------------------------

def _scalar(raw: str):
    raw = raw.strip()
    if not raw:
        return ""
    if len(raw) > 1 and raw[0] in "\"'" and raw[-1] == raw[0]:
        return raw[1:-1]
    for cast in (int, float):
        try:
            return cast(raw)
        except ValueError:
            pass
    return {"true": True, "false": False, "null": None}.get(raw.lower(), raw)


def load_bands(path: str) -> dict:
    """Parse the restricted subset bands.yaml is allowed to use.

    Top-level `key: value`, and lists of flat `- key: value` maps. Nothing else:
    no anchors, no deeper nesting, no multi-line strings. The shipped file says
    so in its first comment so the constraint is not left to discovery.
    """
    try:
        lines = open(path, encoding="utf-8").readlines()
    except OSError as exc:
        raise WatchError(f"cannot read bands file {path}: {exc}") from exc

    config: dict = {}
    current_list: list | None = None
    current_item: dict | None = None

    for lineno, raw in enumerate(lines, 1):
        line = raw.split(" #", 1)[0].rstrip() if " #" in raw else raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        stripped = line.lstrip()
        indent = len(line) - len(stripped)

        if stripped.startswith("- "):
            if current_list is None:
                raise WatchError(f"{path}:{lineno}: list item outside a list")
            current_item = {}
            current_list.append(current_item)
            stripped = stripped[2:].strip()
            if not stripped:
                continue

        if ":" not in stripped:
            raise WatchError(f"{path}:{lineno}: expected 'key: value'")
        key, _, value = stripped.partition(":")
        key, value = key.strip(), value.strip()

        if indent == 0:
            if value:
                current_list = current_item = None
                config[key] = _scalar(value)
            else:
                current_item = None
                current_list = config[key] = []
        elif current_item is not None:
            current_item[key] = _scalar(value)
        else:
            raise WatchError(f"{path}:{lineno}: unexpected indentation")

    return config


# ---------------------------------------------------------------------------
# CI history
# ---------------------------------------------------------------------------

def fetch_runs(repo: str, branch: str, limit: int) -> list[dict]:
    if not shutil.which("gh"):
        raise WatchError(
            "`gh` is not on PATH. The Stage 6 detector reads CI history through "
            "the GitHub CLI; install it, or remove the sdlc-watch workflow."
        )
    proc = subprocess.run(
        ["gh", "run", "list", "--repo", repo, "--branch", branch,
         "--limit", str(limit), "--json", "conclusion,createdAt,workflowName"],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        raise WatchError(f"`gh run list` failed: {proc.stderr.strip() or 'no output'}")
    try:
        return json.loads(proc.stdout or "[]")
    except json.JSONDecodeError as exc:
        raise WatchError(f"`gh run list` returned unparseable JSON: {exc}") from exc


def daily_failure_rate(runs, window_days, min_runs, today=None):
    """One (date, failure rate) point per day, oldest first.

    Days with too few runs are dropped — one run on a quiet Sunday is a coin
    flip, not a signal. Conclusions other than success/failure are not evidence
    either way.
    """
    now = today or dt.datetime.now(dt.timezone.utc)
    cutoff = now - dt.timedelta(days=window_days)
    buckets: dict[str, list[bool]] = defaultdict(list)

    for run in runs:
        conclusion = (run.get("conclusion") or "").lower()
        if conclusion not in ("success", "failure"):
            continue
        try:
            when = dt.datetime.fromisoformat((run.get("createdAt") or "").replace("Z", "+00:00"))
        except ValueError:
            continue
        if when < cutoff:
            continue
        buckets[when.date().isoformat()].append(conclusion == "failure")

    return [(day, sum(v) / len(v)) for day in sorted(buckets)
            if len(v := buckets[day]) >= min_runs]


def history_span_days(points) -> int:
    if len(points) < 2:
        return 0
    first = dt.date.fromisoformat(points[0][0])
    last = dt.date.fromisoformat(points[-1][0])
    return (last - first).days + 1


# ---------------------------------------------------------------------------
# Detection — Western Electric rules over the rolling baseline
# ---------------------------------------------------------------------------

def detect(points) -> dict:
    """The highest sigma level the recent history trips, and why.

    One-sided: only excursions above the mean count. CI becoming more reliable
    is not an incident.
    """
    values = [v for _, v in points]
    mean = statistics.fmean(values)
    sigma = statistics.stdev(values) if len(values) > 1 else 0.0
    latest_day, latest = points[-1]

    result = {"sigma_level": 0, "rule": "", "mean": mean, "sigma": sigma,
              "latest": latest, "latest_day": latest_day, "points": points}
    if sigma == 0:
        # A flat line has no excursions to find, and dividing by it is worse.
        return result

    def above(index, k):
        return values[index] > mean + k * sigma

    recent = list(range(len(values)))[-8:]

    if above(len(values) - 1, 3):
        result.update(sigma_level=3, rule="one point beyond 3 sigma")
    elif len(recent) >= 3 and sum(above(i, 2) for i in recent[-3:]) >= 2:
        result.update(sigma_level=2, rule="2 of the last 3 days beyond 2 sigma")
    elif len(recent) >= 5 and sum(above(i, 1) for i in recent[-5:]) >= 4:
        result.update(sigma_level=1, rule="4 of the last 5 days beyond 1 sigma")
    elif len(recent) == 8 and all(values[i] > mean for i in recent):
        result.update(sigma_level=1, rule="8 consecutive days above the mean")
    return result


def band_action(config, sigma_level):
    """Highest configured band at or below the tripped sigma level."""
    if sigma_level == 0:
        return "none", ""
    best = ("none", "", -1)
    for band in config.get("bands") or []:
        try:
            band_sigma = int(band.get("sigma", 0))
        except (TypeError, ValueError):
            continue
        action = str(band.get("action", "")).strip()
        if action in ACTIONS and best[2] < band_sigma <= sigma_level:
            best = (action, str(band.get("name", "")), band_sigma)
    return best[0], best[1]


# ---------------------------------------------------------------------------
# Write-back — the one place a model is invoked
# ---------------------------------------------------------------------------

def summarise(finding, band_name, repo) -> str:
    lines = [
        f"Repository: {repo}",
        "Metric: CI test failure rate on the default branch",
        f"Band breached: {band_name or 'unnamed'} ({finding['sigma_level']} sigma)",
        f"Rule: {finding['rule']}",
        f"Baseline mean: {finding['mean']:.3f}   Standard deviation: {finding['sigma']:.3f}",
        f"Latest day ({finding['latest_day']}): {finding['latest']:.3f}",
        "",
        "Daily failure rate, oldest first:",
    ]
    lines += [f"  {day}  {value:.3f}" for day, value in finding["points"]]
    return "\n".join(lines)


def _git_status(cwd="."):
    proc = subprocess.run(["git", "status", "--porcelain"], cwd=cwd,
                          capture_output=True, text=True)
    return proc.stdout if proc.returncode == 0 else None


def write_back(finding, band_name, repo, artifact_dir, template_path, open_pr):
    """Invoke Claude read-only, write the intent here, and prove nothing else moved.

    R22's "and nothing else" cannot be enforced by asking nicely, so the model
    gets no write tools and the working tree is compared before and after.
    """
    if not shutil.which("claude"):
        raise WatchError("`claude` is not on PATH; cannot produce a diagnosis.")
    try:
        template = open(template_path, encoding="utf-8").read()
    except OSError as exc:
        raise WatchError(f"cannot read intent template {template_path}: {exc}") from exc

    before = _git_status()
    today = dt.date.today().isoformat()
    prompt = f"""A Stage 6 detector has flagged drift in this repository's CI test
failure rate. Diagnose it and write the next intent.md.

{summarise(finding, band_name, repo)}

Investigate read-only: recent commits, workflow definitions and the failing runs.
Then output an intent.md in exactly the template below and nothing else — no
preamble, no code fences, no commentary after it.

Author: sdlc-watch. Owner: leave as <name> for a human to claim. Status: draft.
Date: {today}.

Problem carries the evidence above plus what you found. Keep scenarios in plain
words; this has not been through the spec transition. If the drift is explained
by something that changes no behaviour, say so and use the no-scenario-changes
wording.

Template:

{template}
"""
    proc = subprocess.run(
        ["claude", "-p", prompt, "--allowed-tools",
         "Read,Grep,Glob,Bash(gh run list:*),Bash(gh run view:*),Bash(git log:*),Bash(git show:*)"],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        raise WatchError(f"`claude -p` failed: {proc.stderr.strip() or 'no output'}")
    body = proc.stdout.strip()
    if not body:
        raise WatchError("`claude -p` produced no diagnosis.")

    after = _git_status()
    if before is not None and after is not None and before != after:
        subprocess.run(["git", "checkout", "--", "."], capture_output=True)
        raise WatchError(
            "the diagnosis run modified the working tree, which it must not do. "
            "Reverted and stopped; nothing was written."
        )

    os.makedirs(artifact_dir, exist_ok=True)
    target = os.path.join(artifact_dir, f"intent-ci-drift-{today}.md")
    with open(target, "w", encoding="utf-8") as fh:
        fh.write(body.rstrip() + "\n")

    if open_pr:
        _open_pr(target, today, finding)
    return target


def _open_pr(target, today, finding):
    branch = f"sdlc-watch/ci-drift-{today}"
    body = (f"Opened by the Stage 6 detector.\n\n    {finding['rule']}\n\n"
            "This is a draft intent for a human owner to claim, not a fix.")
    for step in (
        ["git", "checkout", "-b", branch],
        ["git", "add", target],
        ["git", "commit", "-m", f"intent: CI failure rate drift ({finding['rule']})"],
        ["git", "push", "-u", "origin", branch],
        ["gh", "pr", "create", "--title", f"Intent: CI failure rate drift ({today})",
         "--body", body],
    ):
        proc = subprocess.run(step, capture_output=True, text=True)
        if proc.returncode != 0:
            raise WatchError(f"{' '.join(step[:3])} failed: {proc.stderr.strip()}")


# ---------------------------------------------------------------------------

def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--bands", required=True)
    ap.add_argument("--repo", help="OWNER/NAME; required unless --runs-from is used")
    ap.add_argument("--branch", default="main")
    ap.add_argument("--limit", type=int, default=500)
    ap.add_argument("--runs-from", help="read gh-shaped JSON from a file instead of calling gh")
    ap.add_argument("--today", help="treat this ISO date as now (testing)")
    ap.add_argument("--dry-run", action="store_true", help="detect and report; never write")
    ap.add_argument("--github-output", help="file to append GitHub Actions outputs to")
    ap.add_argument("--write-back", action="store_true")
    ap.add_argument("--artifact-dir", default="docs/sdlc")
    ap.add_argument("--intent-template", default=".sdlc/intent-template.md")
    args = ap.parse_args(argv)

    try:
        config = load_bands(args.bands)
        window = int(config.get("window_days", 30))
        min_history = int(config.get("min_history_days", 30))
        min_qualifying = int(config.get("min_qualifying_days", 20))
        min_runs = int(config.get("min_runs_per_day", 1))

        if args.runs_from:
            runs = json.load(open(args.runs_from, encoding="utf-8"))
        elif args.repo:
            runs = fetch_runs(args.repo, args.branch, args.limit)
        else:
            raise WatchError("one of --repo or --runs-from is required")

        today = None
        if args.today:
            today = dt.datetime.fromisoformat(args.today).replace(tzinfo=dt.timezone.utc)
        points = daily_failure_rate(runs, window, min_runs, today)

        # Both checks, because either alone admits a useless baseline: a long
        # span with three data points, or twenty busy days inside one week.
        span = history_span_days(points)
        if span < min_history or len(points) < min_qualifying:
            raise WatchError(
                f"insufficient history: {span} calendar days spanned and "
                f"{len(points)} qualifying days, against {min_history} and "
                f"{min_qualifying} required. A baseline this short is noise, so "
                f"no detection ran."
            )

        finding = detect(points)
        action, band_name = band_action(config, finding["sigma_level"])
    except WatchError as exc:
        print(f"sdlc-watch: {exc}", file=sys.stderr)
        return 2

    print(f"sdlc-watch: {finding['latest_day']} failure rate {finding['latest']:.3f} "
          f"(mean {finding['mean']:.3f}, sigma {finding['sigma']:.3f}) -> {action}"
          + (f" [{band_name}]" if band_name else ""))
    if finding["rule"]:
        print(f"sdlc-watch: rule tripped — {finding['rule']}")

    if args.github_output:
        with open(args.github_output, "a", encoding="utf-8") as fh:
            fh.write(f"action={action}\nband={band_name}\n"
                     f"sigma_level={finding['sigma_level']}\n")

    if args.write_back and not args.dry_run and action in ("diagnose", "propose_pr"):
        try:
            target = write_back(finding, band_name, args.repo, args.artifact_dir,
                                args.intent_template, open_pr=(action == "propose_pr"))
        except WatchError as exc:
            print(f"sdlc-watch: {exc}", file=sys.stderr)
            return 2
        print(f"sdlc-watch: diagnosis written to {target}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
