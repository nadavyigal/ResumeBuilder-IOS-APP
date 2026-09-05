"""Offline regression checks for public cohort and maturity boundaries."""
import argparse
import datetime as dt
import unittest
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
        self.assertIn("max(properties.is_internal_tester IN ('true', 'True'))", sql)

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
