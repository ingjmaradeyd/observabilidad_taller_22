import ast
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


SERVICE_ROOT = Path(__file__).resolve().parents[1]
ACTIVITY_ROOT = SERVICE_ROOT.parent
sys.path.insert(0, str(SERVICE_ROOT))

from app.config import Settings  # noqa: E402


class CriticalRegressionTests(unittest.TestCase):
    def test_database_budget_stays_below_service_a_timeout(self):
        with patch.dict(
            os.environ,
            {
                "DB_CONNECT_TIMEOUT_SECONDS": "1",
                "DB_POOL_TIMEOUT_SECONDS": "0.25",
                "DB_STATEMENT_TIMEOUT_MS": "1500",
                "DB_LOCK_TIMEOUT_MS": "500",
                "UPSTREAM_HTTP_TIMEOUT_SECONDS": "5",
            },
        ):
            settings = Settings.from_environment()

        self.assertLess(
            settings.maximum_database_wait_seconds,
            settings.upstream_http_timeout_seconds,
        )
        self.assertEqual(settings.maximum_database_wait_seconds, 4.25)
        self.assertLess(settings.db_lock_timeout_ms, settings.db_statement_timeout_ms)

        database_source = (SERVICE_ROOT / "app" / "database.py").read_text()
        self.assertIn("pool_timeout=settings.db_pool_timeout_seconds", database_source)
        self.assertIn('"connect_timeout": settings.db_connect_timeout_seconds', database_source)
        self.assertIn("statement_timeout=", database_source)
        self.assertIn("lock_timeout=", database_source)
        self.assertIn("max_overflow=0", database_source)

        with patch.dict(
            os.environ,
            {
                "DB_CONNECT_TIMEOUT_SECONDS": "1",
                "DB_POOL_TIMEOUT_SECONDS": "1",
                "DB_STATEMENT_TIMEOUT_MS": "1500",
                "DB_LOCK_TIMEOUT_MS": "500",
                "UPSTREAM_HTTP_TIMEOUT_SECONDS": "5",
            },
        ):
            with self.assertRaises(ValueError):
                Settings.from_environment()

    def test_health_is_async_and_does_not_touch_database_or_chaos(self):
        source = (SERVICE_ROOT / "app" / "main.py").read_text()
        module = ast.parse(source)
        health = next(
            node
            for node in module.body
            if isinstance(node, ast.AsyncFunctionDef) and node.name == "health"
        )
        referenced_names = {
            node.id for node in ast.walk(health) if isinstance(node, ast.Name)
        }

        self.assertNotIn("repository", referenced_names)
        self.assertNotIn("order_service", referenced_names)
        self.assertNotIn("chaos", referenced_names)

    def test_data_service_requires_idempotency_header(self):
        source = (SERVICE_ROOT / "app" / "main.py").read_text()

        self.assertIn('alias="Idempotency-Key"', source)
        self.assertIn("Header(\n        ...,", source)
        self.assertIn("idempotency_key=idempotency_key", source)
        self.assertIn('"IDEMPOTENCY_CONFLICT"', source)

        gameday_script = (ACTIVITY_ROOT / "gameday" / "k6" / "pedidos.js").read_text()
        self.assertIn("'Idempotency-Key'", gameday_script)

    def test_local_schema_persists_unique_idempotency_key_and_fingerprint(self):
        schema = (ACTIVITY_ROOT / "gameday" / "db" / "init.sql").read_text()
        migration = (
            ACTIVITY_ROOT
            / "gameday"
            / "db"
            / "migrations"
            / "002-pedidos-idempotency.sql"
        ).read_text()

        self.assertIn("idempotency_key TEXT", schema)
        self.assertIn("request_fingerprint CHAR(64)", schema)
        self.assertIn("ADD COLUMN IF NOT EXISTS idempotency_key", migration)
        self.assertIn("pedidos_idempotency_key_uq", migration)

        repository = (SERVICE_ROOT / "app" / "repository.py").read_text()
        self.assertIn("ON CONFLICT (idempotency_key) DO UPDATE", repository)
        self.assertIn("RETURNING", repository)
        self.assertIn("request_fingerprint", repository)
        self.assertNotIn("find_by_idempotency_key", repository)

    def test_compose_binds_data_service_to_localhost_only(self):
        compose = (
            ACTIVITY_ROOT / "observabilidad" / "docker-compose.gameday.yml"
        ).read_text()

        self.assertIn('"127.0.0.1:8002:8002"', compose)
        self.assertNotIn('\n      - "8002:8002"', compose)


if __name__ == "__main__":
    unittest.main()
