import time

from opentelemetry import trace

from app.buscar_cliente_service_b import buscar_cliente
from app.repository import crear_pedido_cliente
from app.telemetry.metrics import (
    pedidos_fallidos,
    pedidos_creados,
    duracion_creacion_pedido
)


tracer = trace.get_tracer(__name__)


async def crear_pedido(
    id_cliente: int,
    producto: str,
    cantidad: int,
    valor: float
):

    inicio = time.perf_counter()

    try:

        with tracer.start_as_current_span(
            "buscar_cliente"
        ) as span:

            span.set_attribute(
                "cliente.id",
                id_cliente
            )

            cliente = await buscar_cliente(
                id_cliente
            )

            span.set_attribute(
                "cliente.encontrado",
                cliente is not None
            )

        if cliente is None:

            pedidos_fallidos.add(
                1,
                {
                    "motivo": "cliente_no_encontrado"
                }
            )

            return None

        with tracer.start_as_current_span(
            "crear_pedido"
        ) as span:

            span.set_attribute(
                "pedido.producto",
                producto
            )

            span.set_attribute(
                "pedido.cantidad",
                cantidad
            )

            pedido = crear_pedido_cliente(
                id_pedidos=0,
                id_cliente=id_cliente,
                producto=producto,
                cantidad=cantidad,
                valor=valor
            )

            pedidos_creados.add(
                1,
                {
                    "resultado": "exitoso"
                }
            )

            return pedido

    except Exception:

        pedidos_fallidos.add(
            1,
            {
                "motivo": "error_interno"
            }
        )

        raise

    finally:

        duracion_ms = (
            time.perf_counter() - inicio
        ) * 1000

        duracion_creacion_pedido.record(
            duracion_ms
        )