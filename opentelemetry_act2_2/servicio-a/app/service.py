import time

from opentelemetry import trace

from app.dependencies import create_order_in_data_service, find_customer
from app.telemetry.metrics import (
    pedidos_fallidos,
    pedidos_creados,
    duracion_creacion_pedido
)
from app.workflow import create_order_workflow


tracer = trace.get_tracer(__name__)


async def crear_pedido(
    id_cliente: int,
    producto: str,
    cantidad: int,
    valor: float,
    idempotency_key: str,
):
    inicio = time.perf_counter()

    try:
        async def customer_lookup(customer_id: int):
            with tracer.start_as_current_span("service_b.customer_lookup") as span:
                customer = await find_customer(customer_id)
                span.set_attribute("lookup.found", customer is not None)
                return customer

        async def order_creator(payload: dict[str, object]):
            with tracer.start_as_current_span("data_service.order_create"):
                return await create_order_in_data_service(
                    payload,
                    idempotency_key=idempotency_key,
                )

        payload = {
            "id_cliente": id_cliente,
            "producto": producto,
            "cantidad": cantidad,
            "valor": valor,
        }
        pedido = await create_order_workflow(
            payload,
            customer_lookup=customer_lookup,
            order_creator=order_creator,
        )

        if pedido is None:
            pedidos_fallidos.add(
                1,
                {
                    "motivo": "cliente_no_encontrado"
                }
            )
            return None

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
                "motivo": "dependencia_o_error_interno"
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
