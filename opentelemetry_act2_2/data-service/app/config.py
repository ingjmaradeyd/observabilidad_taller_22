import os
from dataclasses import dataclass
from urllib.parse import quote_plus


def _read_bool(name: str, default: bool) -> bool:
    raw_value = os.getenv(name)
    if raw_value is None:
        return default
    return raw_value.strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    db_host: str
    db_port: int
    db_name: str
    db_user: str
    db_password: str
    db_connect_timeout_seconds: int
    db_pool_timeout_seconds: float
    db_statement_timeout_ms: int
    db_lock_timeout_ms: int
    db_pool_size: int
    upstream_http_timeout_seconds: float
    otel_enabled: bool
    otlp_endpoint: str
    chaos_enabled: bool
    chaos_error_rate: float

    @property
    def database_url(self) -> str:
        return (
            "postgresql+psycopg://"
            f"{quote_plus(self.db_user)}:{quote_plus(self.db_password)}@"
            f"{self.db_host}:{self.db_port}/{self.db_name}"
        )

    @property
    def maximum_database_wait_seconds(self) -> float:
        statement_and_commit_seconds = 2 * self.db_statement_timeout_ms / 1000
        return (
            self.db_pool_timeout_seconds
            + self.db_connect_timeout_seconds
            + statement_and_commit_seconds
        )

    @classmethod
    def from_environment(cls) -> "Settings":
        settings = cls(
            db_host=os.getenv("DB_HOST", "localhost"),
            db_port=int(os.getenv("DB_PORT", "5432")),
            db_name=os.getenv("DB_NAME", "opentelemetry_bd"),
            db_user=os.getenv("DB_USER", "postgres"),
            db_password=os.getenv("DB_PASSWORD", ""),
            db_connect_timeout_seconds=int(
                os.getenv("DB_CONNECT_TIMEOUT_SECONDS", "1")
            ),
            db_pool_timeout_seconds=float(
                os.getenv("DB_POOL_TIMEOUT_SECONDS", "0.25")
            ),
            db_statement_timeout_ms=int(
                os.getenv("DB_STATEMENT_TIMEOUT_MS", "1500")
            ),
            db_lock_timeout_ms=int(os.getenv("DB_LOCK_TIMEOUT_MS", "500")),
            db_pool_size=int(os.getenv("DB_POOL_SIZE", "4")),
            upstream_http_timeout_seconds=float(
                os.getenv("UPSTREAM_HTTP_TIMEOUT_SECONDS", "5")
            ),
            otel_enabled=_read_bool("OTEL_ENABLED", True),
            otlp_endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "localhost:4317"),
            chaos_enabled=_read_bool("CHAOS_ENABLED", False),
            chaos_error_rate=float(os.getenv("CHAOS_ERROR_RATE", "0.10")),
        )
        if settings.maximum_database_wait_seconds >= settings.upstream_http_timeout_seconds:
            raise ValueError("database timeout budget must be below the upstream timeout")
        if settings.db_lock_timeout_ms >= settings.db_statement_timeout_ms:
            raise ValueError("database lock timeout must be below statement timeout")
        return settings


settings = Settings.from_environment()
