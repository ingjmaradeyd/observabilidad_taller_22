import sys
import unittest
from pathlib import Path


SERVICE_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVICE_ROOT))

from app.dependencies import (  # noqa: E402
    DataServiceIdempotencyConflict,
    DataServiceUnavailable,
    ServiceBUnavailable,
    create_order_in_data_service,
    find_customer,
)
from app.workflow import create_order_workflow  # noqa: E402


ORDER_PAYLOAD = {
    "id_cliente": 1,
    "producto": "OBSERVABILITY-LAB",
    "cantidad": 1,
    "valor": 1000.0,
}


class FakeResponse:
    def __init__(self, status_code, body=None):
        self.status_code = status_code
        self._body = body or {}

    def json(self):
        return self._body


class FakeClient:
    def __init__(self, response):
        self.response = response
        self.requests = []

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, traceback):
        return False

    async def get(self, url):
        self.requests.append(("GET", url, None, None))
        return self.response

    async def post(self, url, json, headers):
        self.requests.append(("POST", url, json, headers))
        return self.response


class ServiceAClientTests(unittest.IsolatedAsyncioTestCase):
    async def test_only_real_service_b_404_means_customer_not_found(self):
        missing_client = FakeClient(FakeResponse(404))
        unavailable_client = FakeClient(FakeResponse(503))

        missing = await find_customer(
            1,
            base_url="http://service-b:8001",
            client_factory=lambda: missing_client,
        )

        self.assertIsNone(missing)
        with self.assertRaises(ServiceBUnavailable):
            await find_customer(
                1,
                base_url="http://service-b:8001",
                client_factory=lambda: unavailable_client,
            )

    async def test_data_service_client_propagates_trace_context(self):
        data_client = FakeClient(
            FakeResponse(201, {"id_pedidos": 7, **ORDER_PAYLOAD})
        )

        def inject_trace(headers):
            headers["traceparent"] = (
                "00-0af7651916cd43dd8448eb211c80319c-"
                "b7ad6b7169203331-01"
            )

        result = await create_order_in_data_service(
            ORDER_PAYLOAD,
            idempotency_key="public-order-7",
            base_url="http://data-service:8002",
            client_factory=lambda: data_client,
            trace_injector=inject_trace,
        )

        method, url, payload, headers = data_client.requests[0]
        self.assertEqual(method, "POST")
        self.assertEqual(url, "http://data-service:8002/pedidos")
        self.assertEqual(payload, ORDER_PAYLOAD)
        self.assertIn("traceparent", headers)
        self.assertEqual(headers["Idempotency-Key"], "public-order-7")
        self.assertEqual(result["id_pedidos"], 7)

    async def test_data_service_5xx_is_a_dependency_failure(self):
        data_client = FakeClient(FakeResponse(503, {"code": "DATABASE_UNAVAILABLE"}))

        with self.assertRaises(DataServiceUnavailable) as raised:
            await create_order_in_data_service(
                ORDER_PAYLOAD,
                idempotency_key="public-order-failure",
                base_url="http://data-service:8002",
                client_factory=lambda: data_client,
                trace_injector=lambda headers: None,
            )

        self.assertEqual(raised.exception.code, "DATA_SERVICE_UNAVAILABLE")

    async def test_data_service_idempotency_conflict_remains_http_conflict(self):
        data_client = FakeClient(
            FakeResponse(409, {"code": "IDEMPOTENCY_CONFLICT"})
        )

        with self.assertRaises(DataServiceIdempotencyConflict) as raised:
            await create_order_in_data_service(
                ORDER_PAYLOAD,
                idempotency_key="public-order-conflict",
                base_url="http://data-service:8002",
                client_factory=lambda: data_client,
                trace_injector=lambda headers: None,
            )

        self.assertEqual(raised.exception.code, "IDEMPOTENCY_CONFLICT")

    async def test_workflow_validates_customer_before_calling_data_service(self):
        events = []

        async def customer_lookup(customer_id):
            events.append(("customer", customer_id))
            return {"id_cliente": customer_id}

        async def order_creator(payload):
            events.append(("order", payload))
            return {"id_pedidos": 9, **payload}

        result = await create_order_workflow(
            ORDER_PAYLOAD,
            customer_lookup=customer_lookup,
            order_creator=order_creator,
        )

        self.assertEqual(events[0], ("customer", 1))
        self.assertEqual(events[1], ("order", ORDER_PAYLOAD))
        self.assertEqual(result["id_pedidos"], 9)

    def test_public_endpoint_requires_and_forwards_idempotency_header(self):
        source = (SERVICE_ROOT / "app" / "main.py").read_text()

        self.assertIn('alias="Idempotency-Key"', source)
        self.assertIn("Header(\n        ...,", source)
        self.assertIn("idempotency_key=idempotency_key", source)
        self.assertIn("except DataServiceIdempotencyConflict:", source)
        self.assertIn('"code": "IDEMPOTENCY_CONFLICT"', source)

    def test_public_contract_rejects_coercive_and_non_finite_numbers(self):
        source = (SERVICE_ROOT / "app" / "main.py").read_text()

        self.assertIn('@validator("id_cliente", "cantidad", pre=True)', source)
        self.assertIn('@validator("valor", pre=True)', source)
        self.assertIn("math.isfinite", source)


if __name__ == "__main__":
    unittest.main()
