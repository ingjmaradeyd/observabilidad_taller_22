import os


def _read_bool(name: str, default: bool) -> bool:
    raw_value = os.getenv(name)
    if raw_value is None:
        return default
    return raw_value.strip().lower() in {"1", "true", "yes", "on"}


def _read_non_negative_int(name: str, default: int) -> int:
    raw_value = os.getenv(name)
    if raw_value is None:
        return default

    try:
        value = int(raw_value.strip())
    except ValueError as error:
        raise ValueError(f"{name} must be a non-negative integer") from error

    if value < 0:
        raise ValueError(f"{name} must be a non-negative integer")
    return value


class Settings:
    def __init__(self):
        self.DB_HOST = os.getenv("DB_HOST")
        self.DB_PORT = int(os.getenv("DB_PORT", "5432"))
        self.DB_NAME = os.getenv("DB_NAME")
        self.DB_USER = os.getenv("DB_USER")
        self.DB_PASSWORD = os.getenv("DB_PASSWORD")
        self.CHAOS_ENABLED = _read_bool("CHAOS_ENABLED", False)
        self.CHAOS_LATENCY_MS = _read_non_negative_int("CHAOS_LATENCY_MS", 0)


settings = Settings()
