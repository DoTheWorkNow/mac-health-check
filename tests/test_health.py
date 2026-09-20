"""Behavioral regression tests; never invoke real cleanup or native probes."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SNAPSHOT = {
    "cpu": {"usage": 20}, "memory": {"swap_used": 1024, "swap_total": 1024},
    "process_stale": False, "top_processes": [],
}


class HealthTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name)
        self.bin = self.path / "bin"
        self.bin.mkdir()
        self.calls = self.path / "calls"
        self.env = dict(os.environ, PATH=str(self.bin), CALLS=str(self.calls),
                        SNAPSHOT=json.dumps(SNAPSHOT), STATUS_RC="0", CLEAN_RC="0")
        for name in ("bash", "dirname", "date", "jq", "sort", "head"):
            location = shutil.which(name)
            self.assertIsNotNone(location, name)
            (self.bin / name).symlink_to(location)
        self.command("mo", '''
printf '%s\\n' "$*" >> "$CALLS"
case "$*" in
  'status --json') printf '%s\\n' "$SNAPSHOT"; exit "$STATUS_RC" ;;
  'clean --dry-run') echo 'WARNING: fixture inaccessible category'; echo 'Potential space: 2GB'; exit "$CLEAN_RC" ;;
  *) echo 'Forbidden invocation' >&2; exit 99 ;;
esac
''')
        for name in ("sysctl", "vm_stat", "memory_pressure", "top", "ps", "df", "uptime", "pmset"):
            self.command(name, 'echo "fixture probe denied" >&2; exit 1')

    def command(self, name, body):
        script = self.bin / name
        script.write_text("#!/bin/bash\n" + body)
        script.chmod(0o755)

    def run_health(self, *args):
        return subprocess.run(["/bin/bash", str(ROOT / "scripts/health.sh"), *args],
                              env=self.env, text=True, capture_output=True, timeout=10)

    def test_default_only_requests_json(self):
        result = self.run_health()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls.read_text().splitlines(), ["status --json"])
        self.assertIn("not a pressure score", result.stdout)
        self.assertIn("Pressure (reported): unknown", result.stdout)
        self.assertIn("unavailable/zero reading", result.stdout)
        self.assertNotIn("0°C", result.stdout)

    def test_stale_process_and_alert_are_visible(self):
        data = dict(SNAPSHOT, process_stale=True, process_alerts=[{"pid": 12}],
                    top_processes=[{"name": "App With Spaces", "pid": 12, "cpu": 150,
                                    "memory_bytes": 20381696}])
        self.env["SNAPSHOT"] = json.dumps(data)
        result = self.run_health()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("STALE", result.stdout)
        self.assertIn("App With Spaces", result.stdout)
        self.assertIn("RSS 19.4 MiB", result.stdout)
        self.assertIn("see freshness above", result.stdout)

    def test_invalid_empty_wrong_schema_fall_back(self):
        for payload in ("", "not json", "null", "[]", "{}", '{"cpu":{},"memory":{},"disks":"invalid"}'):
            with self.subTest(payload=payload):
                self.env["SNAPSHOT"] = payload
                result = self.run_health()
                self.assertIn("native fallback", result.stdout)
                self.assertIn("WARNING: process data unavailable", result.stdout)
                self.assertNotIn("=== MAC SYSTEM HEALTH (Mole)", result.stdout)

    def test_nonzero_status_with_valid_json_falls_back(self):
        self.env["STATUS_RC"] = "7"
        self.assertIn("native fallback", self.run_health().stdout)

    def test_missing_mole_reports_preview_unavailable(self):
        (self.bin / "mo").unlink()
        result = self.run_health("--deep")
        self.assertEqual(result.returncode, 1)
        self.assertIn("native fallback", result.stdout)
        self.assertIn("preview unavailable", result.stdout)

    def test_missing_jq_does_not_drop_explicit_preview(self):
        (self.bin / "jq").unlink()
        result = self.run_health("--deep")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("native fallback", result.stdout)
        self.assertEqual(self.calls.read_text().splitlines(), ["clean --dry-run"])

    def test_preview_preserves_warning_and_failure_code(self):
        self.env["CLEAN_RC"] = "6"
        result = self.run_health("--deep")
        self.assertEqual(result.returncode, 6)
        self.assertIn("inaccessible category", result.stdout)
        self.assertIn("failed/partial", result.stderr)
        self.assertEqual(self.calls.read_text().splitlines(), ["status --json", "clean --dry-run"])

    def test_help_and_unknown_args_do_not_probe(self):
        self.assertEqual(self.run_health("--help").returncode, 0)
        self.assertEqual(self.run_health("--clean").returncode, 2)
        self.assertFalse(self.calls.exists())

    def test_native_process_names_and_rss_sort(self):
        (self.bin / "mo").unlink()
        self.command("ps", "printf '11 1 1 200000 /Applications/My App\\n12 1 90 100000 /Other App\\n'")
        result = self.run_health()
        self.assertIn("/Applications/My App", result.stdout)
        rss_section = result.stdout.split("(RSS order)", 1)[1]
        self.assertLess(rss_section.index("11 1"), rss_section.index("12 1"))


if __name__ == "__main__":
    unittest.main()
