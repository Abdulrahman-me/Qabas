from collections.abc import AsyncIterator

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.runtime import Resources
from tests.learning.conftest import curriculum_settings, learn_api  # noqa: F401  (fixture re-export)


@pytest.fixture
async def world(learn_api: TestClient, curriculum_settings: Settings) -> AsyncIterator[tuple[TestClient, Resources]]:  # noqa: F811
    """The real app over the loaded test curriculum (no learners yet) and service-level resources on it."""
    resources = Resources.create(curriculum_settings)
    yield learn_api, resources
    await resources.close()
