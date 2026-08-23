import os
from fastapi import FastAPI, HTTPException
from app.repository import get_cliente
from app.telemetry.tracing import configurar_tracing
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from app.telemetry.logging_config import configurar_logging

OTEL_ENABLED = os.getenv("OTEL_ENABLED", "true").lower() == "true"

if OTEL_ENABLED:
    configurar_tracing()
    configurar_logging()

app = FastAPI(
    title = "Servicio Clientes - Servicio B",
    version = "1.0.0"
)

if OTEL_ENABLED:
    FastAPIInstrumentor.instrument_app(app)

@app.get("/health")
@app.get("/service-b/health")
def health():
    return{
        "service":"Servicio Clientes",
        "status":"EJECUTANDO"
    }


@app.get("/clientes/{cliente_id}")
@app.get("/service-b/clientes/{cliente_id}")
def get_customer(cliente_id:int):
    datos = get_cliente(cliente_id)
    if datos is None:
        raise HTTPException(
            status_code=404,
            detail="Cliente no encontrado"
        )
    return datos