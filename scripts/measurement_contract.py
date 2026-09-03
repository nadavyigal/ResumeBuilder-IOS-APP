#!/usr/bin/env python3
"""Run the pinned weekly measurement contract for Resumely, end to end.

WHY THIS FILE EXISTS
--------------------
The contract lives in Builder OS
`02-Products/2026-08-15-weekly-measurement-contracts-and-gated-packets.md`. It
specifies seven mandatory steps and says a skipped step invalidates the read.
As a written ritual it has run exactly once (2026-08-15, before the cohort could
mature) and has now been missed for six consecutive releases. A measurement that
depends on someone remembering seven steps is not a measurement.

So it is a command:

    python3 scripts/measurement_contract.py

Two runs on the same day must print byte-identical output. Every time bound
below is therefore day-aligned to UTC midnight, and the read is stated "as of"
that instant. Non-determinism is the specific defect this contract exists to
eliminate: the same gate previously answered "2 of 20", "4 of 20" and 0 because
the window, the version scope and the exclusion level were free parameters.

THE FIVE THINGS THAT SILENTLY CHANGE THE NUMBER IF YOU GET THEM WRONG
--------------------------------------------------------------------
1. Primary activation is `optimization_completed`. `export_success` is a
   SECONDARY DIAGNOSTIC and is printed under its own heading, never as the
   headline. (Agentic OS `north_star.py` queries the diagnostic; do not copy it.)
2. Exclusion is person-level: `max(is_internal_tester)` per `person_id`, then
   filter. Event-level filtering splits one human across both sides.
3. Version scope is exact `app_version` AND `build_number`. Builds 19-27 all
   report `app_version = 1.4.9`; version alone is not a cohort.
4. n is stated with every rate. Below n=10 at a step, counts only, read labelled
   `immature`.
5. A cohort younger than 168 hours prints `not yet measurable` and its earliest
   valid date. Never a partial figure.

Step 3 is the integrity check and is not skippable: if a build's last event
predates its own store release, the cohort contains no public users and the read
is zero. That one comparison would have caught every prior bad read.

CREDENTIALS
-----------
`AGENTIC_OS_POSTHOG_API_KEY` is read from the environment, falling back to
`~/.config/agentic-os.env` (the same loader Agentic OS uses). It is never
printed, never written to a file, and never passed on a command line. If it is
absent this script stops; it has no fallback.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBXPROJ = ROOT / "ResumeBuilder IOS APP.xcodeproj" / "project.pbxproj"
PROGRESS = ROOT / "tasks" / "progress.md"

POSTHOG_BASE_URL = "https://us.posthog.com"
POSTHOG_KEY_ENV = "AGENTIC_OS_POSTHOG_API_KEY"
LOCAL_ENV_FILE = Path.home() / ".config" / "agentic-os.env"
TIMEOUT_SEC = 90

# --- Pinned by the contract. Do not move without re-pinning the contract. ----
PROJECT_ID = 270848
BUNDLE_ID = "Resumebuilder-IOS.ResumeBuilder-IOS-APP"
LIB = "resumely-ios-urlsession"
DENOMINATOR_EVENT = "resume_file_selected"
FUNNEL_MIDDLE_EVENT = "optimization_started"
PRIMARY_ACTIVATION_EVENT = "optimization_completed"
SECONDARY_DIAGNOSTIC_EVENT = "export_success"
DEFAULT_WINDOW_DAYS = 30
D7_HOURS = 168
MIN_N_FOR_A_RATE = 10

# "No number crosses a boundary date." Each of these changed what the events
# mean, so a window spanning one is comparing two different metrics.
BOUNDARIES = {
    datetime.date(2026, 6, 18): "score engine change",
    datetime.date(2026, 8, 12): "optimization_completed split",
    datetime.date(2026, 8, 14): "free ATS score",
}

# The project is confirmed by event shape before any number is read: the MCP
# banner has previously claimed one project while serving another.
FINGERPRINT_EVENTS = (DENOMINATOR_EVENT, PRIMARY_ACTIVATION_EVENT, SECONDARY_DIAGNOSTIC_EVENT)
FINGERPRINT_DAYS = 90


class ContractError(RuntimeError):
    """A step could not be completed honestly. Stop; do not estimate."""


# ---------------------------------------------------------------- plumbing --


def load_api_key() -> str:
    key = os.environ.get(POSTHOG_KEY_ENV)
    if key:
        return key
    if LOCAL_ENV_FILE.is_file():
        for raw in LOCAL_ENV_FILE.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[7:].strip()
            name, _, value = line.partition("=")
            if name.strip() == POSTHOG_KEY_ENV:
                value = value.strip().strip('"').strip("'")
                if value:
                    return value
    raise ContractError(
        f"{POSTHOG_KEY_ENV} is not set and is not in {LOCAL_ENV_FILE}. "
        "This script has no fallback key by design; export it and re-run."
    )


def query(sql: str, api_key: str) -> list[list]:
    request = urllib.request.Request(
        f"{POSTHOG_BASE_URL}/api/projects/{PROJECT_ID}/query/",
        data=json.dumps({"query": {"kind": "HogQLQuery", "query": sql}}).encode("utf-8"),
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SEC) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raise ContractError(f"PostHog returned HTTP {exc.code} for project {PROJECT_ID}") from exc
    except (urllib.error.URLError, TimeoutError, OSError, json.JSONDecodeError) as exc:
        raise ContractError(f"PostHog read failed: {exc}") from exc
    results = payload.get("results")
    return results if isinstance(results, list) else []


def apple_lookup() -> tuple[str, datetime.datetime]:
    """Step 1. Cache-busted, so the anchor is Apple's answer and not a cached one.

    The anchor is never a repo claim and never `progress.md`: repo status has
    been wrong about this app's live state three times.
    """
    cache_buster = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d%H%M%S%f")
    url = f"https://itunes.apple.com/lookup?bundleId={BUNDLE_ID}&country=us&_cb={cache_buster}"
    request = urllib.request.Request(url, headers={"Cache-Control": "no-cache"})
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SEC) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, OSError, json.JSONDecodeError) as exc:
        raise ContractError(f"Apple lookup failed: {exc}") from exc
    results = payload.get("results") or []
    if not results:
        raise ContractError(f"Apple lookup returned no result for {BUNDLE_ID}")
    entry = results[0]
    version, released = entry.get("version"), entry.get("currentVersionReleaseDate")
    if not version or not released:
        raise ContractError("Apple lookup is missing version or currentVersionReleaseDate")
    anchor = datetime.datetime.strptime(released, "%Y-%m-%dT%H:%M:%SZ").replace(
        tzinfo=datetime.timezone.utc
    )
    return version, anchor


def repo_build_settings() -> tuple[str | None, str | None]:
    """What `main` claims it shipped. `scripts/validate-store-version.sh` guards it."""
    try:
        text = PBXPROJ.read_text(encoding="utf-8")
    except OSError:
        return None, None

    def one(key: str) -> str | None:
        found = sorted({value.strip() for value in re.findall(rf"{key} = ([^;]+);", text)})
        return found[0] if len(found) == 1 else None

    return one("MARKETING_VERSION"), one("CURRENT_PROJECT_VERSION")


def parse_ts(value) -> datetime.datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=datetime.timezone.utc)


def stamp(value: datetime.datetime | None) -> str:
    return value.strftime("%Y-%m-%dT%H:%M:%SZ") if value else "-"


def lit(value: str) -> str:
    return "'" + str(value).replace("\\", "\\\\").replace("'", "\\'") + "'"


def dt_lit(value: datetime.datetime) -> str:
    return f"toDateTime({lit(value.strftime('%Y-%m-%d %H:%M:%S'))})"


def iso_utc(text: str) -> datetime.datetime:
    parsed = parse_ts(text)
    if parsed is None:
        raise argparse.ArgumentTypeError(f"not an ISO 8601 timestamp: {text}")
    return parsed.astimezone(datetime.timezone.utc)


def rate(numerator: int, denominator: int) -> str:
    """A percentage is only printable once its denominator is large enough."""
    if denominator < MIN_N_FOR_A_RATE:
        return f"{numerator} of n={denominator} (below n={MIN_N_FOR_A_RATE}: counts only)"
    return f"{numerator}/{denominator} = {numerator / denominator * 100:.1f}%"


# ------------------------------------------------------------------ steps ---


def window_start(as_of: datetime.datetime) -> tuple[datetime.datetime, str]:
    """Trailing 30 days, clamped forward so no number crosses a boundary date."""
    start = as_of - datetime.timedelta(days=DEFAULT_WINDOW_DAYS)
    note = f"trailing {DEFAULT_WINDOW_DAYS} days"
    for boundary, reason in sorted(BOUNDARIES.items()):
        edge = datetime.datetime.combine(boundary, datetime.time.min, tzinfo=datetime.timezone.utc)
        if start < edge <= as_of:
            start, note = edge, f"clamped to the {boundary.isoformat()} boundary ({reason})"
    return start, note


def fingerprint(api_key: str, as_of: datetime.datetime) -> list[tuple[str, int]]:
    """Step 2. Confirm the project by event shape before reading any number."""
    start = as_of - datetime.timedelta(days=FINGERPRINT_DAYS)
    rows = query(
        f"""
SELECT event, count() AS n
FROM events
WHERE timestamp >= {dt_lit(start)} AND timestamp < {dt_lit(as_of)}
  AND properties.$lib = {lit(LIB)}
GROUP BY event
ORDER BY n DESC, event ASC
""",
        api_key,
    )
    shape = [(str(row[0]), int(row[1])) for row in rows]
    if not shape:
        raise ContractError(
            f"Fingerprint failed: project {PROJECT_ID} has no `{LIB}` events in "
            f"{FINGERPRINT_DAYS} days. Refusing to read a project it cannot identify."
        )
    names = {name for name, _ in shape}
    missing = [event for event in FINGERPRINT_EVENTS if event not in names]
    if missing:
        raise ContractError(
            f"Fingerprint failed: project {PROJECT_ID} serves `{LIB}` events but never "
            f"{', '.join('`' + name + '`' for name in missing)} in {FINGERPRINT_DAYS} days. "
            "This is not the Resumely event shape."
        )
    return shape


def build_split(api_key: str, start: datetime.datetime, as_of: datetime.datetime) -> list[dict]:
    """Step 3. Per-build first/last seen — the input to the integrity check."""
    rows = query(
        f"""
SELECT properties.app_version AS app_version,
       properties.build_number AS build_number,
       count() AS events,
       count(DISTINCT person_id) AS people,
       min(timestamp) AS first_seen,
       max(timestamp) AS last_seen
FROM events
WHERE timestamp >= {dt_lit(start)} AND timestamp < {dt_lit(as_of)}
  AND properties.$lib = {lit(LIB)}
GROUP BY app_version, build_number
ORDER BY first_seen ASC
""",
        api_key,
    )
    return [
        {
            "app_version": row[0] or "(unset)",
            "build_number": row[1] or "(unset)",
            "events": int(row[2]),
            "people": int(row[3]),
            "first_seen": parse_ts(row[4]),
            "last_seen": parse_ts(row[5]),
        }
        for row in rows
    ]


def cohort_funnel(
    api_key: str,
    version: str,
    build: str,
    start: datetime.datetime,
    as_of: datetime.datetime,
) -> dict:
    """Steps 4 and 5 in one pass: person-level exclusion, then an ordered funnel.

    Internal-ness and cohort membership are decided per `person_id` over the
    whole window. The funnel timestamps are scoped to the exact build, so a
    person who upgraded mid-window contributes only their in-cohort path, and
    each step requires the previous step's timestamp to come first.
    """
    in_cohort = (
        f"(properties.app_version = {lit(version)} AND properties.build_number = {lit(build)})"
    )

    def first(event: str, alias: str) -> str:
        return f"min(if(event = {lit(event)} AND {in_cohort}, timestamp, NULL)) AS {alias}"

    # Three levels, and the levels matter. Computing the step booleans in the
    # same SELECT that aggregates them silently returns 0 for every person in
    # HogQL — `min(...) IS NOT NULL` there evaluated false even where the
    # timestamp existed. Aggregate first, derive the booleans one level up,
    # count them one level above that. Outer aliases are deliberately distinct
    # from the inner column names: reusing them raises `illegal_aggregation`.
    rows = query(
        f"""
SELECT
  countIf(cohort AND NOT internal)                                   AS ext_people,
  countIf(cohort AND NOT internal AND selected)                      AS ext_selected,
  countIf(cohort AND NOT internal AND selected AND started)          AS ext_started,
  countIf(cohort AND NOT internal AND selected AND started AND done) AS ext_completed,
  countIf(cohort AND NOT internal AND selected AND exported)         AS ext_exported,
  countIf(cohort AND internal)                                       AS int_people,
  countIf(cohort AND internal AND selected)                          AS int_selected,
  countIf(cohort AND internal AND selected AND started)              AS int_started,
  countIf(cohort AND internal AND selected AND started AND done)     AS int_completed,
  countIf(cohort AND internal AND selected AND exported)             AS int_exported
FROM (
  SELECT
    internal,
    cohort,
    isNotNull(t_sel)                AS selected,
    ifNull(t_start >= t_sel, 0)     AS started,
    ifNull(t_done >= t_start, 0)    AS done,
    ifNull(t_export >= t_sel, 0)    AS exported
  FROM (
    SELECT
      person_id,
      max(properties.is_internal_tester IN ('true', 'True')) AS internal,
      max({in_cohort})                                       AS cohort,
      {first(DENOMINATOR_EVENT, "t_sel")},
      {first(FUNNEL_MIDDLE_EVENT, "t_start")},
      {first(PRIMARY_ACTIVATION_EVENT, "t_done")},
      {first(SECONDARY_DIAGNOSTIC_EVENT, "t_export")}
    FROM events
    WHERE timestamp >= {dt_lit(start)} AND timestamp < {dt_lit(as_of)}
      AND properties.$lib = {lit(LIB)}
    GROUP BY person_id
  )
)
""",
        api_key,
    )
    if not rows:
        raise ContractError("Funnel query returned no rows")
    keys = (
        "ext_people ext_selected ext_started ext_completed ext_exported "
        "int_people int_selected int_started int_completed int_exported"
    ).split()
    return dict(zip(keys, (int(value) for value in rows[0])))


# ----------------------------------------------------------------- report ---


def build_report(args, api_key: str) -> tuple[str, str]:
    """Return (full report text, the one-block record for step 7)."""
    now = datetime.datetime.now(datetime.timezone.utc)
    # Day-aligned, so two runs on the same day agree byte for byte.
    as_of = datetime.datetime.combine(now.date(), datetime.time.min, tzinfo=datetime.timezone.utc)
    start, window_note = window_start(as_of)

    out: list[str] = []
    add = out.append
    add("Resumely weekly measurement contract")
    add("=" * 72)
    add(f"Contract      : Builder OS 2026-08-15-weekly-measurement-contracts-and-gated-packets")
    add(f"PostHog       : project {PROJECT_ID}, $lib = {LIB}")
    add(f"Read as of    : {stamp(as_of)} (day-aligned; two runs on one day agree)")
    add(f"Window        : {stamp(start)} .. {stamp(as_of)} ({window_note})")
    add("")

    # ---- Step 1 ---------------------------------------------------------
    live_version, release_ts = apple_lookup()
    add("Step 1  Apple lookup (cache-busted)")
    add(f"        live version        : {live_version}")
    add(f"        store release       : {stamp(release_ts)}  <- the anchor")
    repo_version, repo_build = repo_build_settings()
    add(f"        repo MARKETING_VER  : {repo_version or 'unreadable'}")
    add(f"        repo CURRENT_PROJ   : {repo_build or 'unreadable'}")
    if repo_version and repo_version != live_version:
        add(f"        WARNING: repo says {repo_version}, the store serves {live_version}.")
        add("                 Run scripts/validate-store-version.sh.")
    add("")

    version = args.version or live_version
    if version != live_version:
        if not args.released:
            raise ContractError(
                f"--version {version} is not the live version ({live_version}), so the Apple "
                "lookup's timestamp is the wrong anchor for it. Pass --released with that "
                "version's own store release timestamp (ISO 8601, UTC). The anchor is never "
                "inferred and never taken from progress.md."
            )
        release_ts = args.released
        add(f"        ANCHOR OVERRIDE: reading {version}, so the anchor is the supplied")
        add(f"                         {stamp(release_ts)} rather than {live_version}'s.")
        add("")
    build = args.build or repo_build
    if not build:
        raise ContractError(
            "No build number: pass --build N, or make CURRENT_PROJECT_VERSION readable "
            "in project.pbxproj. The scope is exact version AND build; version alone is "
            "not a cohort."
        )
    build_source = "--build" if args.build else "project.pbxproj CURRENT_PROJECT_VERSION"
    add(f"Cohort        : app_version = {version}, build_number = {build} (from {build_source})")
    add("")

    # ---- Step 2 ---------------------------------------------------------
    shape = fingerprint(api_key, as_of)
    add(f"Step 2  Project fingerprint ({FINGERPRINT_DAYS}d of {LIB} events, top 8 of "
        f"{len(shape)} names)")
    for name, count in shape[:8]:
        add(f"        {name:<34} {count:>8}")
    signature = dict(shape)
    add("        signature events required by the contract:")
    for name in FINGERPRINT_EVENTS:
        add(f"          {name:<32} {signature.get(name, 0):>8}")
    add("        OK: all present, so this is the Resumely event shape.")
    add("")

    # ---- Step 3 ---------------------------------------------------------
    splits = build_split(api_key, start, as_of)
    add("Step 3  Version/build split, with the pre-release integrity check")
    add(f"        {'app_version':<12} {'build':<7} {'events':>7} {'people':>7}  "
        f"{'first_seen':<21} {'last_seen':<21} verdict")
    cohort_row = None
    for row in splits:
        verdict = "-"
        if row["app_version"] == version:
            if row["last_seen"] and row["last_seen"] < release_ts:
                verdict = "PRE-RELEASE"
            else:
                verdict = "post-release"
        if row["app_version"] == version and str(row["build_number"]) == str(build):
            cohort_row = row
            verdict += "  <- cohort"
        add(f"        {str(row['app_version']):<12} {str(row['build_number']):<7} "
            f"{row['events']:>7} {row['people']:>7}  {stamp(row['first_seen']):<21} "
            f"{stamp(row['last_seen']):<21} {verdict}")
    add("")

    headline: str
    detail: list[str] = []

    if cohort_row is None:
        headline = "0 activations — the exact build has emitted no events in the window"
        add(f"        Integrity check: no rows for {version} ({build}). Reporting zero.")
    elif cohort_row["last_seen"] and cohort_row["last_seen"] < release_ts:
        headline = "0 activations — cohort is PRE-RELEASE"
        add(f"        Integrity check FIRES: last event {stamp(cohort_row['last_seen'])} "
            f"precedes the store release {stamp(release_ts)}.")
        add("        A cohort whose last event predates its own public release contains no")
        add("        public users. Per the contract, stop here and report zero.")
    if cohort_row is None or (cohort_row["last_seen"] and cohort_row["last_seen"] < release_ts):
        add("")
        add("Steps 4 and 5  not run — step 3 stopped the read. This is the contract's")
        add("               behaviour, not a skipped step: there is nothing to exclude")
        add("               from and no funnel to order.")
    add("")

    if cohort_row is not None and not (
        cohort_row["last_seen"] and cohort_row["last_seen"] < release_ts
    ):
        # ---- Steps 4 and 5 ----------------------------------------------
        counts = cohort_funnel(api_key, version, str(build), start, as_of)
        add("Step 4  Person-level exclusion (max(is_internal_tester) per person_id)")
        add(f"        external people in cohort : {counts['ext_people']}")
        add(f"        internal people in cohort : {counts['int_people']}  (reported, never merged)")
        add("")
        add("Step 5  Ordered funnel, external users, exact build")
        add(f"        1. {DENOMINATOR_EVENT:<24} n = {counts['ext_selected']}")
        add(f"        2. {FUNNEL_MIDDLE_EVENT:<24} n = {counts['ext_started']}")
        add(f"        3. {PRIMARY_ACTIVATION_EVENT:<24} n = {counts['ext_completed']}   <- PRIMARY")
        add(f"        activation rate : {rate(counts['ext_completed'], counts['ext_selected'])}")
        add("")
        add("        Internal (same funnel, kept separate):")
        add(f"        1. {DENOMINATOR_EVENT:<24} n = {counts['int_selected']}")
        add(f"        2. {FUNNEL_MIDDLE_EVENT:<24} n = {counts['int_started']}")
        add(f"        3. {PRIMARY_ACTIVATION_EVENT:<24} n = {counts['int_completed']}")
        add("")
        add(f"        SECONDARY DIAGNOSTIC — {SECONDARY_DIAGNOSTIC_EVENT} (never the headline):")
        add(f"        external n = {counts['ext_exported']}, internal n = {counts['int_exported']}")
        add("")
        headline = f"{counts['ext_completed']} external activations"
        detail = [
            f"{DENOMINATOR_EVENT} n={counts['ext_selected']}",
            f"{FUNNEL_MIDDLE_EVENT} n={counts['ext_started']}",
            f"{PRIMARY_ACTIVATION_EVENT} n={counts['ext_completed']}",
            f"{SECONDARY_DIAGNOSTIC_EVENT} (diagnostic) n={counts['ext_exported']}",
        ]
        if counts["ext_selected"] < MIN_N_FOR_A_RATE:
            headline += " — read is IMMATURE (n below 10; counts only)"

    # ---- Step 6 ---------------------------------------------------------
    age_hours = (as_of - release_ts).total_seconds() / 3600
    earliest_valid = release_ts + datetime.timedelta(hours=D7_HOURS)
    add("Step 6  Age check against the metric's own window")
    add(f"        cohort age at read  : {age_hours:.1f}h since {stamp(release_ts)}")
    add(f"        D7 needs            : {D7_HOURS}h elapsed per user")
    if age_hours < D7_HOURS:
        add(f"        VERDICT             : not yet measurable")
        add(f"        earliest valid D7   : {stamp(earliest_valid)}")
        headline = f"not yet measurable — earliest valid D7 read {stamp(earliest_valid)}"
    else:
        add(f"        VERDICT             : mature enough for a D7 read")
    add("")

    # ---- Step 7 ---------------------------------------------------------
    record_lines = [
        f"### Activation read — {version} ({build}) — as of {stamp(as_of)}",
        "",
        f"- **Result:** {headline}",
        f"- Store release anchor: {stamp(release_ts)} (cache-busted Apple lookup, live version {live_version})",
        f"- Window: {stamp(start)} .. {stamp(as_of)} ({window_note})",
        f"- Scope: exact `app_version = {version}` and `build_number = {build}`, `$lib = {LIB}`",
        f"- Primary activation `{PRIMARY_ACTIVATION_EVENT}`; `{SECONDARY_DIAGNOSTIC_EVENT}` is the secondary diagnostic only",
        f"- Earliest valid D7 read: {stamp(earliest_valid)}",
    ]
    if detail:
        record_lines.append(f"- External funnel: {'; '.join(detail)}")
    record_lines.append(f"- Produced by `scripts/measurement_contract.py`, all seven steps.")
    record = "\n".join(record_lines)

    add("Step 7  Record (paste into tasks/progress.md and the living page's Current State)")
    add("-" * 72)
    add(record)
    add("-" * 72)
    add("")
    add(f"HEADLINE: {headline}")
    return "\n".join(out) + "\n", record


def write_record(record: str) -> str:
    """Step 7's write half. Idempotent: the same read replaces its own block."""
    title = record.splitlines()[0]
    text = PROGRESS.read_text(encoding="utf-8")
    block = record.rstrip() + "\n"
    if title in text:
        pattern = re.compile(
            re.escape(title) + r"\n(?:(?!\n### |\n## ).)*", re.DOTALL
        )
        text = pattern.sub(block.rstrip() + "\n", text, count=1)
        action = "replaced"
    else:
        marker = "# Project Progress\n"
        if marker not in text:
            raise ContractError(f"{PROGRESS} has no '# Project Progress' heading to insert under")
        text = text.replace(marker, marker + "\n" + block, 1)
        action = "inserted"
    PROGRESS.write_text(text, encoding="utf-8")
    return f"{action} into {PROGRESS.relative_to(ROOT)}"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run the pinned Resumely measurement contract, all seven steps."
    )
    parser.add_argument(
        "--app", default="resumely", choices=["resumely"],
        help="Only Resumely lives in this repo; the flag exists so the command reads "
             "the same as the contract's runnable form.",
    )
    parser.add_argument("--version", help="app_version to scope to (default: the live App Store version)")
    parser.add_argument("--build", help="build_number to scope to (default: CURRENT_PROJECT_VERSION)")
    parser.add_argument(
        "--released", type=iso_utc,
        help="Store release timestamp for a --version that is no longer the live one "
             "(ISO 8601, UTC). Required in that case: Apple only reports the live "
             "version's release date, and using it for an older cohort mis-anchors step 3.",
    )
    parser.add_argument(
        "--write", action="store_true",
        help="Also write step 7's record into tasks/progress.md (idempotent).",
    )
    args = parser.parse_args()

    try:
        api_key = load_api_key()
        report, record = build_report(args, api_key)
    except ContractError as exc:
        print(f"STOPPED: {exc}", file=sys.stderr)
        return 2

    print(report, end="")
    if args.write:
        try:
            print(write_record(record))
        except (ContractError, OSError) as exc:
            print(f"STOPPED before writing: {exc}", file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
