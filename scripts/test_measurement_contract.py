"""Offline regression checks for public cohort and maturity boundaries."""
import argparse
import datetime as dt
import unittest
import sqlite3
import re
from unittest.mock import patch
import measurement_contract as contract

UTC = dt.timezone.utc


class MeasurementContractTests(unittest.TestCase):
    def test_missing_environment_key_stops_without_reading_files(self):
        with patch.dict(contract.os.environ, {}, clear=True), patch.object(contract.Path, 'read_text', side_effect=AssertionError('must not read credential files')):
            with self.assertRaisesRegex(contract.ContractError, 'only from the environment'):
                contract.load_api_key()

    def test_environment_key_is_used(self):
        with patch.dict(contract.os.environ, {contract.POSTHOG_KEY_ENV: 'synthetic-test-key'}, clear=True):
            self.assertEqual(contract.load_api_key(), 'synthetic-test-key')

    def test_release_and_maturity_are_scoped_without_narrowing_internal_exclusion(self):
        start = dt.datetime(2026, 8, 14, tzinfo=UTC)
        end = dt.datetime(2026, 9, 12, tzinfo=UTC)
        release = dt.datetime(2026, 9, 2, 19, 44, 22, tzinfo=UTC)
        with patch.object(contract, 'query', return_value=[[0] * 11]) as query:
            contract.cohort_funnel('synthetic', '1.5.0', '28', start, end, release)
        sql = query.call_args.args[0]
        # Public membership/funnel timestamps are clamped, while a tester flag
        # from before the release still excludes that entire person.
        self.assertIn("timestamp >= toDateTime('2026-09-02 19:44:22')", sql)
        self.assertIn("t_sel <= toDateTime('2026-09-05 00:00:00')", sql)
        self.assertIn("t_sel > toDateTime('2026-09-05 00:00:00')", sql)
        self.assertIn("WHERE timestamp >= toDateTime('2026-08-14 00:00:00')", sql)
        self.assertIn("SELECT id FROM persons WHERE lower(toString(properties.is_internal_tester)) IN ('true', '1')", sql)

    def test_actual_funnel_predicates_exclude_late_internal_and_immature_people(self):
        start = dt.datetime(2026, 8, 14, tzinfo=UTC)
        end = dt.datetime(2026, 9, 20, tzinfo=UTC)
        release = dt.datetime(2026, 9, 2, tzinfo=UTC)
        with patch.object(contract, 'query', return_value=[[0] * 11]) as query:
            contract.cohort_funnel('synthetic', '1.5.0', '28', start, end, release)
        sql = query.call_args.args[0]
        # Execute the generated aggregation over adversarial fixture rows.
        # Translate only dialect functions/time literals, not funnel logic.
        sql = sql.replace('INTERVAL 168 HOUR', str(168 * 3600))
        for name in ['app_version', 'build_number', '$lib', 'is_internal_tester']:
            sql = sql.replace('properties.' + name, '"properties.' + name + '"')
        db = sqlite3.connect(':memory:')
        self.addCleanup(db.close)
        db.create_function('toDateTime', 1, lambda value: dt.datetime.fromisoformat(value).replace(tzinfo=UTC).timestamp())
        db.create_function('toString', 1, lambda value: str(value) if value is not None else None)
        db.create_function('if', 3, lambda condition, yes, no: yes if condition else no)
        class CountIf:
            def __init__(self): self.value = 0
            def step(self, condition): self.value += bool(condition)
            def finalize(self): return self.value
        db.create_aggregate('countIf', 1, CountIf)
        db.execute('CREATE TABLE persons (id TEXT, "properties.is_internal_tester" TEXT)')
        db.execute('CREATE TABLE events (person_id TEXT, event TEXT, timestamp REAL, "properties.app_version" TEXT, "properties.build_number" TEXT, "properties.$lib" TEXT)')
        def event(person, name, day):
            stamp = release.timestamp() + day * 86400
            db.execute('INSERT INTO events VALUES (?, ?, ?, ?, ?, ?)', (person, name, stamp, '1.5.0', '28', contract.LIB))
        def journey(person, selection, completion):
            event(person, 'resume_file_selected', selection)
            event(person, 'optimization_started', selection + 0.01)
            event(person, 'optimization_completed', completion)
            event(person, 'export_success', completion)
        for person in ['valid', 'late', 'boundary', 'pending', 'internal', 'mixed']:
            db.execute('INSERT INTO persons VALUES (?, ?)', (person, 'true' if person == 'internal' else 'false'))
        journey('valid', 1, 2)
        journey('late', 1, 9)  # mature selection; conversion outside D7
        journey('boundary', 1, 8)  # exactly 168 hours is accepted
        journey('pending', 17, 17.5)  # completion does not make a young cohort mature
        journey('internal', 1, 2)  # current flag, with no event-level flag at all
        journey('mixed', -2, -1)  # prerelease success must not leak into public funnel
        event('mixed', 'resume_file_selected', 1)
        actual = tuple(db.execute(sql).fetchone())
        self.assertEqual(actual, (5, 4, 3, 2, 2, 1, 1, 1, 1, 1, 1))

    def report(self, selected, started, completed):
        now = dt.datetime.now(UTC)
        release = now - dt.timedelta(days=20)
        counts = dict.fromkeys('ext_people ext_selected ext_started ext_completed ext_exported int_people int_selected int_started int_completed int_exported ext_pending'.split(), 0)
        counts.update(ext_selected=selected, ext_started=started, ext_completed=completed, ext_pending=3)
        rows = [dict(app_version='1.5.0', build_number='28', events=20, people=12, first_seen=release, last_seen=now-dt.timedelta(days=1))]
        args = argparse.Namespace(version=None, build=None, released=None)
        with patch.object(contract, 'apple_lookup', return_value=('1.5.0', release)), patch.object(contract, 'repo_build_settings', return_value=('1.5.0', '28')), patch.object(contract, 'fingerprint', return_value=[(name, 20) for name in contract.FINGERPRINT_EVENTS]), patch.object(contract, 'build_split', return_value=rows), patch.object(contract, 'cohort_funnel', return_value=counts):
            return contract.build_report(args, 'synthetic')[0]

    def test_one_small_step_suppresses_rate(self):
        report = self.report(20, 15, 9)
        self.assertNotIn('%', report)
        self.assertIn('IMMATURE', report)
        self.assertIn('immature selections : 3', report)

    def test_all_mature_steps_allow_rate_with_denominator(self):
        report = self.report(20, 15, 10)
        self.assertIn('10/20 = 50.0%', report)

    def test_empty_mature_cohort_prints_no_percentage(self):
        self.assertNotIn('%', self.report(0, 0, 0))


if __name__ == '__main__':
    unittest.main()
