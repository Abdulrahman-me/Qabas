"""How a stage attempt ends when it does not produce an accepted artifact (factory §13.1: "Stage failures retry
twice, then set status=failed with error")."""

from __future__ import annotations


class StageOutputInvalid(Exception):
    """The stage's output failed the factory's own code checks. Retried (the issues reach the next attempt as
    feedback), then the run fails with ``code``."""

    def __init__(self, code: str, issues: list[str]) -> None:
        super().__init__(f"{code}: " + "; ".join(issues))
        self.code, self.issues = code, issues


class StageBlocked(Exception):
    """A precondition only a person can resolve (curriculum, specialist, provider approval). Never retried and
    never worked around by generation: the run fails with this blocker as its error (D-85)."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(f"{code}: {message}")
        self.code, self.message = code, message
