"""Regression checks for the App Store screenshot generator and validator.

PR #201 review: with CAPTURE_IPAD=0 the generator validated the iPhone set and
then failed on five missing iPad images, because it never passed
`--iphone-only`. These tests run the real scripts on a fresh directory of
synthetic, opaque, unique PNGs, without a simulator (SKIP_CAPTURE=1).

Run: python3 -m unittest discover -s scripts -p 'test_app_store_screenshot_scripts.py'
"""
from __future__ import annotations

import os
import struct
import subprocess
import tempfile
import unittest
import zlib
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
GENERATOR = SCRIPTS / "generate-app-store-screenshots.sh"
VALIDATOR = SCRIPTS / "validate-app-store-screenshots.sh"
NAMES = ["01-tailor", "02-blockers", "03-ai-edits", "04-templates", "05-expert"]


def write_png(path: Path, width: int, height: int, shade: int) -> None:
    """An opaque 8-bit RGB PNG in one flat colour; `shade` makes each file unique."""
    row = b"\x00" + bytes((shade, 40, 90)) * width
    raw = row * height

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    )


def make_iphone_only_set(root: Path) -> None:
    folder = root / "iphone-6.3-1206x2622"
    folder.mkdir(parents=True)
    for index, name in enumerate(NAMES):
        write_png(folder / f"{name}.png", 1206, 2622, 20 + index * 30)


def run(command: list[str], env: dict[str, str] | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(command, capture_output=True, text=True, env={**os.environ, **(env or {})}, timeout=300)


class ValidatorTests(unittest.TestCase):
    def test_iphone_only_set_passes_with_flag(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_iphone_only_set(Path(tmp))
            result = run([str(VALIDATOR), tmp, "5", "--iphone-only"])
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("PASS", result.stdout)

    def test_iphone_only_set_fails_without_flag(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_iphone_only_set(Path(tmp))
            result = run([str(VALIDATOR), tmp, "5"])
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("iPad 13-inch", result.stderr)


class GeneratorValidationTests(unittest.TestCase):
    """The generator itself must pass --iphone-only when CAPTURE_IPAD=0."""

    def generate(self, tmp: str, capture_ipad: str) -> subprocess.CompletedProcess:
        return run(
            ["zsh", str(GENERATOR)],
            env={
                "SKIP_CAPTURE": "1",
                "CAPTURE_IPAD": capture_ipad,
                "IPHONE_DIR": "iphone-6.3-1206x2622",
                "OUTPUT": tmp,
            },
        )

    def test_capture_ipad_off_validates_iphone_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_iphone_only_set(Path(tmp))
            result = self.generate(tmp, "0")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("iPhone 6.3-inch (Dynamic Island, medium display): PASS", result.stdout)
            self.assertNotIn("iPad 13-inch", result.stdout + result.stderr)

    def test_capture_ipad_on_still_requires_ipad(self):
        with tempfile.TemporaryDirectory() as tmp:
            make_iphone_only_set(Path(tmp))
            result = self.generate(tmp, "1")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("iPad 13-inch", result.stderr)


class GeneratorMatchesRendererTests(unittest.TestCase):
    """tasks/lessons.md 2026-10-19: the generator kept looping 1 to 10 after the
    renderer went to 5 slots, so the stale June set stayed live for months.
    Fail as soon as the two disagree."""

    def test_generator_names_match_marketing_slots(self):
        import re
        swift = (SCRIPTS.parent / "ResumeBuilder IOS APP" / "Features" / "V2" / "Marketing" / "MarketingScreenshotView.swift").read_text()
        enum = re.search(r"enum MarketingScreenshotSlot[^{]*\{(.*?)\n    var id", swift, re.S).group(1)
        slots = re.findall(r"^\s*case (\w+)", enum, re.M)
        kebab = [re.sub(r"(?<!^)([A-Z])", r"-\1", name).lower() for name in slots]

        script = GENERATOR.read_text()
        names = re.search(r"^names=\((.*?)^\)", script, re.S | re.M).group(1).split()

        self.assertEqual(len(slots), 5, slots)
        self.assertEqual(names, kebab)
        self.assertEqual([n.split("-", 1)[1] for n in NAMES], kebab)


if __name__ == "__main__":
    unittest.main()
