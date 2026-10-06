"""Download failures cannot install unverified canonical scripture."""

import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import httpx

from scripts import fetch_mushaf


class FetchMushafTests(unittest.TestCase):
    def test_timeout_returns_failure_without_installing(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with patch.object(fetch_mushaf.sys, "argv", ["fetch_mushaf.py"]), \
                    patch.object(fetch_mushaf, "get_settings", return_value=SimpleNamespace(mushaf_dir=root)), \
                    patch.object(fetch_mushaf.httpx, "Client", side_effect=httpx.ConnectTimeout("timeout")):
                self.assertEqual(fetch_mushaf.main(), 1)
            self.assertEqual(list(root.iterdir()), [])

    def test_wrong_download_digest_does_not_install(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            response = MagicMock(content=b"not the pinned archive")
            client = MagicMock()
            client.__enter__.return_value.get.return_value = response
            with patch.object(fetch_mushaf.sys, "argv", ["fetch_mushaf.py"]), \
                    patch.object(fetch_mushaf, "get_settings", return_value=SimpleNamespace(mushaf_dir=root)), \
                    patch.object(fetch_mushaf.httpx, "Client", return_value=client):
                self.assertEqual(fetch_mushaf.main(), 1)
            self.assertEqual(list(root.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
