import logging

from fastapi import FastAPI, Header, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from pydantic import BaseModel, Field, validator

from app.config import settings
from app.core import (
    ChaosInjected,
    DatabaseUnavailable,
    DeterministicChaos,
    IdempotencyConflict,
    InvalidIdempotencyKey,
    OrderService,
    OrderValidationError,
    is_finite_json_number,
)
from app.repository import SqlAlchemyOrderRepository
from app.telemetry import OtelOrderMetrics, configure_telemetry


logger = logging.getLogger(__name__)
configure_telemetry()

app = FastAPI(title="Data Service", version="1.0.0")
repository = SqlAlchemyOrderRepository()
order_service = OrderService(
    repository=repository,
    chaos=DeterministicChaos(
        enabled=settings.chaos_enabled,
        error_rate=settings.chaos_error_rate,
    ),
    metrics=OtelOrderMetrics(),
)


class PedidoRequest(BaseModel):
    id_cliente: int = Field(gt=0)
    producto: str = Field(min_length=1, max_length=200)
    cantidad: int = Field(gt=0)
    valor: float = Field(gt=0)

    @validator("id_cliente", "cantidad", pre=True)
    def reject_coercive_integers(cls, value):
        if type(value) is not int:
            raise ValueError("value must be an integer")
        return value

    @validator("valor", pre=True)
    def reject_invalid_value(cls, value):
        if not is_finite_json_number(value):
            raise ValueError("value must be a finite number")
        return value

    class Config:
        extra = "forbid"


def _error_response(status_code: int, code: str, message: str) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={"code": code, "message": message},
    )


@app.exception_handler(RequestValidationError)
async def request_validation_error(
    request: Request,
    error: RequestValidationError,
) -> JSONResponse:
    logger.warning(
        "Order request rejected",
        extra={"event_name": "order.validation", "outcome": "rejected"},
    )
    return _error_response(422, "INVALID_ORDER", "Order request is invalid")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"service": "data-service", "status": "UP"}


@app.get("/ready")
def ready():
    try:
        repository.ready()
        return {"service": "data-service", "status": "READY"}
    except DatabaseUnavailable:
        return _error_response(
            503,
            "DATABASE_UNAVAILABLE",
            "Database dependency is unavailable",
        )


@app.post("/pedidos", status_code=201)
def create_order(
    request: PedidoRequest,
    idempotency_key: str = Header(
        ...,
        alias="Idempotency-Key",
        min_length=1,
        max_length=128,
    ),
):
    payload = request.model_dump() if hasattr(request, "model_dump") else request.dict()
    try:
        order = order_service.create_from_mapping(
            payload,
            idempotency_key=idempotency_key,
        )
        logger.info(
            "Order created",
            extra={"event_name": "order.created", "outcome": "success"},
        )
        return order
    except OrderValidationError:
        return _error_response(422, "INVALID_ORDER", "Order request is invalid")
    except InvalidIdempotencyKey:
        return _error_response(
            422,
            "INVALID_IDEMPOTENCY_KEY",
            "Idempotency-Key is invalid",
        )
    except IdempotencyConflict:
        return _error_response(
            409,
            "IDEMPOTENCY_CONFLICT",
            "Idempotency-Key was already used for another request",
        )
    except ChaosInjected:
        logger.warning(
            "Controlled order failure injected",
            extra={"event_name": "chaos.injected", "reason": "configured_rate"},
        )
        return _error_response(503, "CHAOS_INJECTED", "Controlled failure injected")
    except DatabaseUnavailable:
        return _error_response(
            503,
            "DATABASE_UNAVAILABLE",
            "Database dependency is unavailable",
        )


if settings.otel_enabled:
    FastAPIInstrumentor.instrument_app(app)
