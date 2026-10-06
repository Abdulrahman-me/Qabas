"""Deployment supervision checks without starting services or touching a database."""

import unittest
from unittest.mock import MagicMock, patch

from scripts import start_render


class RenderStartTests(unittest.TestCase):
    def test_worker_consumes_reply_and_relay_queues(self) -> None:
        worker, beat, api = start_render.commands("12345")
        self.assertIn("maintenance,raqeeb,embeddings", worker)
        self.assertIn("beat", beat)
        self.assertEqual(api[-2:], ["--port", "12345"])

    @patch.object(start_render.signal, "signal")
    @patch.object(start_render.subprocess, "Popen")
    def test_failed_migration_prevents_start(self, popen: MagicMock, _signal: MagicMock) -> None:
        migration = MagicMock(returncode=1)
        migration.poll.return_value = 1
        popen.return_value = migration
        self.assertEqual(start_render.main(), 1)
        self.assertEqual(popen.call_count, 1)
        self.assertIn("alembic", popen.call_args.args[0])

    @patch.object(start_render.signal, "signal")
    @patch.object(start_render.subprocess, "Popen")
    def test_worker_exit_stops_api_and_beat(self, popen: MagicMock, _signal: MagicMock) -> None:
        migration = MagicMock(returncode=0)
        migration.poll.return_value = 0
        worker = MagicMock()
        worker.poll.return_value = 1
        beat, api = MagicMock(), MagicMock()
        beat.poll.return_value = api.poll.return_value = None
        popen.side_effect = [migration, worker, beat, api]
        with patch.dict(start_render.os.environ, {}, clear=True):
            self.assertEqual(start_render.main(), 1)
        beat.terminate.assert_called_once()
        api.terminate.assert_called_once()

    @patch.object(start_render.signal, "signal")
    @patch.object(start_render.subprocess, "Popen")
    def test_missing_dataset_install_failure_prevents_start(self, popen: MagicMock, _signal: MagicMock) -> None:
        migration = MagicMock(returncode=0)
        migration.poll.return_value = 0
        dataset = MagicMock(returncode=1)
        dataset.poll.return_value = 1
        popen.side_effect = [migration, dataset]
        with patch.dict(start_render.os.environ, {"MUSHAF_ARCHIVE_URL": "https://example.org/pinned.zip"}):
            self.assertEqual(start_render.main(), 1)
        self.assertEqual(popen.call_count, 2)
        self.assertIn("scripts/fetch_mushaf.py", popen.call_args.args[0])

    def test_stuck_child_is_killed(self) -> None:
        child = MagicMock()
        child.poll.return_value = None
        child.wait.side_effect = [start_render.subprocess.TimeoutExpired("test", 15), 0]
        start_render.stop([child])
        child.terminate.assert_called_once()
        child.kill.assert_called_once()


if __name__ == "__main__":
    unittest.main()
