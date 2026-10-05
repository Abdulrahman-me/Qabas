from pathlib import Path

import pytest

from app.services.platform.storage import LocalStorage
from tests.learning.conftest import fresh_curriculum as fresh_curriculum


@pytest.fixture
def storage(tmp_path: Path) -> LocalStorage:
    return LocalStorage(tmp_path, public_base_url="https://cdn.qabas.app/media",
                        private_base_url="https://private.example.test", signing_key=b"test-key")
