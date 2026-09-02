from collections.abc import Callable, MutableMapping
from typing import Any

from app.config import settings


class ServiceBUnavailable(RuntimeError):
    code = "SERVICE_B_UNAVAILABLE"


class DataServiceUnavailable(RuntimeError):
    code = "DATA_SERVICE_UNAVAILABLE"


class DataServiceIdempotencyConflict(RuntimeError):
    code = "IDEMPOTENCY_CONFLICT"


def _default_client_factory():
    import httpx

    return httpx.AsyncClient(timeout=5.0)


def _inject_current_trace(headers: MutableMapping[str, str]) -> None:
    from opentelemetry.propagate import inject

    inject(headers)


async def find_customer(
    customer_id: int,
    *,
    base_url: str | None = None,
    client_factory: Callable[[], Any] | None = None,
):
    service_url = (
        base_url or settings.SERVICE_B_URL or "http://localhost:8001"
    ).rstrip("/")
    factory = client_factory or _default_client_factory

    try:
        async with factory() as client:
            response = await client.get(f"{service_url}/clientes/{customer_id}")
            if response.status_code == 404:
                return None
            if response.status_code != 200:
                raise ServiceBUnavailable("service B returned a non-success response")
            return response.json()
    except ServiceBUnavailable:
        raise
    except Exception as error:
        raise ServiceBUnavailable("service B request failed") from error


async def create_order_in_data_service(
    payload: dict[str, object],
    *,
    idempotency_key: str,
    base_url: str | None = None,
    client_factory: Callable[[], Any] | None = None,
    trace_injector: Callable[[MutableMapping[str, str]], None] | None = None,
):
    service_url = (
        base_url or settings.DATA_SERVICE_URL or "http://localhost:8002"
    ).rstrip("/")
    factory = client_factory or _default_client_factory
    inject_trace = trace_injector or _inject_current_trace
    headers: dict[str, str] = {}
    inject_trace(headers)
    headers["Idempotency-Key"] = idempotency_key

    try:
        async with factory() as client:
            response = await client.post(
                f"{service_url}/pedidos",
                json=payload,
                headers=headers,
            )
            if response.status_code == 409:
                raise DataServiceIdempotencyConflict(
                    "idempotency key conflicts with an existing order"
                )
            if response.status_code != 201:
                raise DataServiceUnavailable(
                    "data-service returned a non-success response"
                )
            return response.json()
    except (DataServiceIdempotencyConflict, DataServiceUnavailable):
        raise
    except Exception as error:
        raise DataServiceUnavailable("data-service request failed") from error
