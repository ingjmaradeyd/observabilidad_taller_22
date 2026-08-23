import os
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
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

@app.get("/health")
@app.get("/service-a/health")
def health():
    return {
        "message":"Servicio Clientes - A",
        "status":"EJECUTANDO"
    }


@app.post("/pedidos/crear")
@app.post("/service-a/pedidos/crear")
async def crear_pedido_endpoint(request: PedidoRequest):
    pedido = await crear_pedido(
        id_cliente = request.id_cliente,
        producto = request.producto,
        cantidad = request.cantidad,
        valor = request.valor
    )

    if pedido is None:
        raise HTTPException(
            status_code=404,
            detail="Cliente no encontrado"
        )

    return pedido


