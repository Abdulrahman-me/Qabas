"""Runtime settings from the environment (OPERATIONS_AND_ENVIRONMENT §19).

Secrets are ``SecretStr`` so they never appear in reprs or logs. Locally the values come from
``backend/.env`` (git-ignored). Provider settings stay optional until their phase integrates them.
"""

from __future__ import annotations

from enum import StrEnum
from functools import lru_cache
from pathlib import Path

from pydantic import Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parents[1]


class Environment(StrEnum):
    dev = "dev"
    test = "test"
    staging = "staging"
    production = "production"


class StorageBackend(StrEnum):
    local = "local"
    s3 = "s3"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=BACKEND_DIR / ".env", extra="ignore")

    app_env: Environment = Environment.dev
    log_level: str = "INFO"

    database_url: str = "postgresql+asyncpg://qabas@127.0.0.1:5432/qabas_dev"
    test_database_url: str | None = None
    redis_url: str = "redis://127.0.0.1:6379/0"

    # Auth (rev 10): HMAC pepper for stored token hashes; the previous value is accepted during rotation.
    auth_token_pepper: SecretStr | None = None
    auth_token_pepper_previous: SecretStr | None = None
    ws_ticket_ttl_seconds: int = 60
    signed_url_ttl_seconds: int = 900
    auth_cache_ttl_seconds: int = 30          # revocation takes effect within this window (backend §5)
    guest_inactivity_days: int = 180
    reviewer_session_hours: int = 12
    last_seen_throttle_seconds: int = 30
    reviewer_lockout_attempts: int = 5
    reviewer_lockout_window_seconds: int = 900
    idempotency_ttl_hours: int = 24
    # Number of trusted reverse proxies in front of the API; 0 = use the socket peer address.
    trusted_proxy_hops: int = 0
    redis_key_prefix: str = "qabas"

    # Contract identity (API §3.2).
    contract_revision: int = 10
    min_client_contract: int = 10
    min_app_version: str = "0.0.0"

    cors_allowed_origins: list[str] = Field(default_factory=list)
    synthetic_league_members: bool = False
    rate_limits_profile: str = "default"

    # LLM and media providers (integrated in later phases).
    anthropic_api_key: SecretStr | None = None
    llm_model_strong: str = "claude-opus-5-5"
    llm_model_fast: str = "claude-haiku-4-5"
    # Per-request timeout; the SDK retries transport errors, 429 and 5xx with backoff this many times (Phase 11).
    llm_timeout_seconds: float = 120.0
    llm_max_retries: int = 2
    stt_provider: str | None = None
    stt_api_key: SecretStr | None = None
    image_provider: str | None = None
    image_api_key: SecretStr | None = None
    tts_provider: str | None = None
    tts_api_key: SecretStr | None = None

    # Sources (Phase 9; docs/SOURCE_POLICY.md). The canonical mushaf is fetched per environment (D-88).
    mushaf_dir: Path = BACKEND_DIR / "var" / "sources" / "mushaf"
    quran_foundation_client_id: str | None = None
    quran_foundation_client_secret: SecretStr | None = None
    quran_mcp_url: str | None = None
    tafsir_mcp_command: str | None = None
    dorar_base_url: str = "http://127.0.0.1:5000"           # the local sidecar (scripts/dorar_sidecar.py)
    dorar_sidecar_dir: Path = BACKEND_DIR / "var" / "sidecars" / "dorar"
    quran_foundation_api_base: str = "https://apis.quran.foundation/content/api/v4"
    quran_foundation_search_base: str = "https://apis.quran.foundation/search"
    quran_foundation_auth_url: str = "https://oauth2.quran.foundation/oauth2/token"
    quran_audio_base_url: str = "https://verses.quran.com/"
    hadeethenc_base_url: str | None = None
    quranenc_base_url: str | None = None
    islamhouse_base_url: str | None = None
    islamhouse_api_key: SecretStr | None = None

    # Object storage: "local" (filesystem, dev/test) or "s3".
    storage_backend: StorageBackend = StorageBackend.local
    local_storage_dir: Path = BACKEND_DIR / "var" / "storage"
    storage_signing_key: SecretStr | None = None
    s3_endpoint: str | None = None
    s3_content_bucket: str | None = None
    s3_private_bucket: str | None = None
    s3_access_key: SecretStr | None = None
    s3_secret_key: SecretStr | None = None
    cdn_base_url: str = "http://127.0.0.1:8000/media"

    # Recitation (Phase 10).
    asr_queue_max: int = 8
    asr_timeout_seconds: int = 15
    # The converted model directory (scripts/convert_recitation_model.py), read only by the asr worker.
    recitation_model_path: Path = BACKEND_DIR / "var" / "models" / "whisper-base-ar-quran-ct2"
    embedding_model: str = "BAAI/bge-m3"
    default_reciter: str = "alafasy"

    @model_validator(mode="after")
    def _require_production_secrets(self) -> Settings:
        if self.app_env in (Environment.staging, Environment.production):
            missing = [
                name
                for name in ("auth_token_pepper", "storage_signing_key")
                if getattr(self, name) is None
            ]
            if missing:
                raise ValueError(f"{self.app_env} requires: {', '.join(missing)}")
            if self.app_env is Environment.production and self.synthetic_league_members:
                raise ValueError("SYNTHETIC_LEAGUE_MEMBERS must be false in production (P-01)")
        return self

    @property
    def is_dev_like(self) -> bool:
        return self.app_env in (Environment.dev, Environment.test)

    @property
    def allows_fixture_content(self) -> bool:
        """The contract's synthetic test curriculum may be loaded and published here (D-29, D-84): dev, test and
        the staging environment frontend integration runs against. Never production."""
        return self.app_env in (Environment.dev, Environment.test, Environment.staging)

    def peppers(self) -> list[bytes]:
        """Current pepper first, then the previous one accepted during rotation."""
        if self.auth_token_pepper is None:
            raise RuntimeError("AUTH_TOKEN_PEPPER is not configured")
        values = [self.auth_token_pepper.get_secret_value().encode()]
        if self.auth_token_pepper_previous is not None:
            values.append(self.auth_token_pepper_previous.get_secret_value().encode())
        return values


@lru_cache
def get_settings() -> Settings:
    return Settings()
