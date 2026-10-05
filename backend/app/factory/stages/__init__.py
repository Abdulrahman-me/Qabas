"""Factory stage executors by stage name (factory §13.1). A stage absent here is not runnable yet."""

from __future__ import annotations

from app.factory.orchestrator import Executor
from app.factory.stages import plan

EXECUTORS: dict[str, Executor] = {
    "plan": plan.run,
}
