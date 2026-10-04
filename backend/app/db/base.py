"""Declarative base, naming convention and shared column helpers."""

from __future__ import annotations

from datetime import date, datetime
from typing import Any, ClassVar

from sqlalchemy import CheckConstraint, Date, DateTime, MetaData, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

# Stable constraint names, so migrations can reference and alter them.
NAMING_CONVENTION = {
    "ix": "ix_%(table_name)s_%(column_0_N_name)s",
    "uq": "uq_%(table_name)s_%(column_0_N_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_N_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}


class Base(DeclarativeBase):
    metadata = MetaData(naming_convention=NAMING_CONVENTION)
    type_annotation_map: ClassVar[dict[Any, Any]] = {
        dict[str, Any]: JSONB,
        list[Any]: JSONB,
        datetime: DateTime(timezone=True),
        date: Date,
    }


class Timestamps:
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(server_default=func.now(), onupdate=func.now())


def sql_list(values: tuple[str | int, ...]) -> str:
    return ", ".join(str(v) if isinstance(v, int) else "'" + v.replace("'", "''") + "'" for v in values)


def enum_check(column: str, values: tuple[str | int, ...], *, name: str | None = None,
               nullable: bool = False) -> CheckConstraint:
    """``column IN (...)`` as a named CHECK; values come from ``app.db.enums`` (contract-derived)."""
    condition = f"{column} IN ({sql_list(values)})"
    if nullable:
        condition = f"{column} IS NULL OR {condition}"
    return CheckConstraint(condition, name=name or f"{column}_valid")


def id_check(column: str, prefix: str, *, name: str | None = None) -> CheckConstraint:
    """Opaque IDs carry their contract prefix (API §3.3), e.g. ``usr_``."""
    return CheckConstraint(f"{column} ~ '^{prefix}_[0-9A-Za-z_]+$'", name=name or f"{column}_format")


SHA256_HEX = "^[0-9a-f]{64}$"
