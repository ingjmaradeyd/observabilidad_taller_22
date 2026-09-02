import os
import math
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, validator
from app.dependencies import (
    DataServiceIdempotencyConflict,
    DataServiceUnavailable,
    ServiceBUnavailable,
)
from app.service import crear_pedido
from app.telemetry.tracing import configurar_tracing
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from app.telemetry.logging_config import configurar_logging

OTEL_ENABLED = os.getenv("OTEL_ENABLED", "true").lower() == "true"

if OTEL_ENABLED:
    configurar_tracing()
    configurar_logging()

app = FastAPI(
    title = "Servicio Clientes - Servicio A",
    version = "1.0.0"
)

if OTEL_ENABLED:
    FastAPIInstrumentor.instrument_app(app)

class PedidoRequest(BaseModel):
    id_cliente: int
    producto: str
    cantidad: int
    valor: float

    @validator("id_cliente", "cantidad", pre=True)
    def reject_coercive_integers(cls, value):
        if type(value) is not int:
            raise ValueError("value must be an integer")
        return value

    @validator("valor", pre=True)
    def reject_invalid_value(cls, value):
        if type(value) not in {int, float}:
            raise ValueError("value must be a finite number")
        try:
            is_finite = math.isfinite(float(value))
        except OverflowError:
            is_finite = False
        if not is_finite:
            raise ValueError("value must be a finite number")
        return value

@app.get("/health")
@app.get("/service-a/health")
def health():
    return {
        "message":"Servicio Clientes - A",
        "status":"EJECUTANDO"
    }


@app.post("/pedidos/crear")
@app.post("/service-a/pedidos/crear")
async def crear_pedido_endpoint(
    request: PedidoRequest,
    idempotency_key: str = Header(
        ...,
        alias="Idempotency-Key",
        min_length=1,
        max_length=128,
    ),
):
    try:
        pedido = await crear_pedido(
            id_cliente = request.id_cliente,
            producto = request.producto,
            cantidad = request.cantidad,
            valor = request.valor,
            idempotency_key=idempotency_key,
        )
    except ServiceBUnavailable:
        raise HTTPException(
            status_code=503,
            detail={
                "code": "SERVICE_B_UNAVAILABLE",
                "message": "Customer service is unavailable"
            }
        )
    except DataServiceUnavailable:
        raise HTTPException(
            status_code=503,
            detail={
                "code": "DATA_SERVICE_UNAVAILABLE",
                "message": "Order data service is unavailable"
            }
        )
    except DataServiceIdempotencyConflict:
        raise HTTPException(
            status_code=409,
            detail={
                "code": "IDEMPOTENCY_CONFLICT",
                "message": "Idempotency-Key was already used for another request"
            }
        )

    if pedido is None:
        raise HTTPException(
            status_code=404,
            detail="Cliente no encontrado"
        )

    return pedido
