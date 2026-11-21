"""Offline checks for ci_scripts/ci_post_clone.sh (Xcode Cloud secrets step)."""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "ci_scripts" / "ci_post_clone.sh"
KEYS = {
    "POSTHOG_API_KEY": "phc_synthetic",
    "SUPABASE_ANON_KEY": "synthetic.anon.key",
    "INTERNAL_TESTER_EMAILS": "tester@example.com",
    "INTERNAL_TESTER_USER_IDS": "00000000-0000-0000-0000-000000000000",
}


class CiPostCloneTests(unittest.TestCase):
    def run_script(self, env):
        base = {"PATH": os.environ["PATH"]}
        base.update(env)
        return subprocess.run([str(SCRIPT)], env=base, capture_output=True, text=True)

    def test_script_is_executable(self):
        self.assertTrue(os.access(SCRIPT, os.X_OK), "Xcode Cloud runs it as zsh without +x")

    def test_writes_all_keys_without_printing_values(self):
        with tempfile.TemporaryDirectory() as repo:
            result = self.run_script({"CI_PRIMARY_REPOSITORY_PATH": repo, **KEYS})
            self.assertEqual(result.returncode, 0, result.stderr)
            written = (Path(repo) / "Secrets.xcconfig").read_text()
            for name, value in KEYS.items():
                self.assertIn(f"{name} = {value}\n", written)
                self.assertNotIn(value, result.stdout + result.stderr)

    def test_double_slash_is_escaped_for_xcconfig(self):
        with tempfile.TemporaryDirectory() as repo:
            env = {"CI_PRIMARY_REPOSITORY_PATH": repo, **KEYS, "SUPABASE_ANON_KEY": "a//b"}
            self.assertEqual(self.run_script(env).returncode, 0)
            self.assertIn("SUPABASE_ANON_KEY = a/$()/b\n", (Path(repo) / "Secrets.xcconfig").read_text())

    def test_missing_or_blank_key_fails_and_writes_nothing(self):
        with tempfile.TemporaryDirectory() as repo:
            env = {"CI_PRIMARY_REPOSITORY_PATH": repo, **KEYS, "INTERNAL_TESTER_USER_IDS": "  "}
            del env["POSTHOG_API_KEY"]
            result = self.run_script(env)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("POSTHOG_API_KEY", result.stderr)
            self.assertIn("INTERNAL_TESTER_USER_IDS", result.stderr)
            self.assertFalse((Path(repo) / "Secrets.xcconfig").exists())

    def test_dollar_sign_is_rejected_because_xcconfig_expands_it(self):
        with tempfile.TemporaryDirectory() as repo:
            env = {"CI_PRIMARY_REPOSITORY_PATH": repo, **KEYS, "INTERNAL_TESTER_EMAILS": "a$(HOME)b"}
            result = self.run_script(env)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("INTERNAL_TESTER_EMAILS", result.stderr)
            self.assertNotIn("a$(HOME)b", result.stderr)
            self.assertFalse((Path(repo) / "Secrets.xcconfig").exists())

    def test_refuses_to_run_outside_xcode_cloud(self):
        result = self.run_script(KEYS)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("only runs on Xcode Cloud", result.stderr)


if __name__ == "__main__":
    unittest.main()
