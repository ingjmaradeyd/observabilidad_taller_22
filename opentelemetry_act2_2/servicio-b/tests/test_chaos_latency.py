import ast
import os
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import patch


SERVICE_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVICE_ROOT))

try:
    from opentelemetry import trace
except ModuleNotFoundError:
    opentelemetry = types.ModuleType("opentelemetry")
    trace = types.ModuleType("opentelemetry.trace")
    trace.get_current_span = lambda: None
    opentelemetry.trace = trace
    sys.modules["opentelemetry"] = opentelemetry
    sys.modules["opentelemetry.trace"] = trace

from app.chaos import inject_configured_latency  # noqa: E402
from app.config import Settings  # noqa: E402


class RecordingSpan:
    def __init__(self):
        self.attributes = {}

    def is_recording(self):
        return True

    def set_attribute(self, name, value):
        self.attributes[name] = value


class ChaosLatencyTests(unittest.TestCase):
    def test_chaos_is_disabled_by_default(self):
        with patch.dict(os.environ, {}, clear=True):
            settings = Settings()

        def unexpected_sleep(_seconds):
            self.fail("sleep must not run when chaos is disabled")

        injected = inject_configured_latency(
            enabled=settings.CHAOS_ENABLED,
            latency_ms=settings.CHAOS_LATENCY_MS,
            sleep=unexpected_sleep,
        )

        self.assertFalse(injected)
        self.assertFalse(settings.CHAOS_ENABLED)
        self.assertEqual(settings.CHAOS_LATENCY_MS, 0)

    def test_enabled_chaos_injects_200_milliseconds(self):
        delays = []
        span = RecordingSpan()

        def record_sleep(seconds):
            delays.append(seconds)

        with patch.dict(
            os.environ,
            {"CHAOS_ENABLED": "true", "CHAOS_LATENCY_MS": "200"},
            clear=True,
        ):
            settings = Settings()

        with patch.object(trace, "get_current_span", return_value=span):
            injected = inject_configured_latency(
                enabled=settings.CHAOS_ENABLED,
                latency_ms=settings.CHAOS_LATENCY_MS,
                sleep=record_sleep,
            )

        self.assertTrue(injected)
        self.assertEqual(delays, [0.2])
        self.assertEqual(span.attributes["chaos.enabled"], True)
        self.assertEqual(span.attributes["chaos.type"], "latency")
        self.assertEqual(span.attributes["chaos.latency_ms"], 200)

    def test_customer_routes_inject_latency_before_repository_query(self):
        module = ast.parse((SERVICE_ROOT / "app" / "main.py").read_text())
        handler = next(
            node
            for node in module.body
            if isinstance(node, ast.FunctionDef) and node.name == "get_customer"
        )
        routes = {
            decorator.args[0].value
            for decorator in handler.decorator_list
            if isinstance(decorator, ast.Call)
        }

        first_statement = handler.body[0]
        repository_query = handler.body[1]

        self.assertEqual(
            routes,
            {"/clientes/{cliente_id}", "/service-b/clientes/{cliente_id}"},
        )
        self.assertIsInstance(first_statement, ast.Expr)
        self.assertEqual(
            first_statement.value.func.id,
            "inject_configured_latency",
        )
        self.assertIsInstance(repository_query, ast.Assign)
        self.assertEqual(repository_query.value.func.id, "get_cliente")

    def test_health_routes_do_not_inject_latency(self):
        module = ast.parse((SERVICE_ROOT / "app" / "main.py").read_text())
        health = next(
            node
            for node in module.body
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
            and node.name == "health"
        )
        routes = {
            decorator.args[0].value
            for decorator in health.decorator_list
            if isinstance(decorator, ast.Call)
        }
        called_functions = {
            node.func.id
            for node in ast.walk(health)
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
        }

        self.assertEqual(routes, {"/health", "/service-b/health"})
        self.assertNotIn("inject_configured_latency", called_functions)
        self.assertNotIn("get_cliente", called_functions)


if __name__ == "__main__":
    unittest.main()
