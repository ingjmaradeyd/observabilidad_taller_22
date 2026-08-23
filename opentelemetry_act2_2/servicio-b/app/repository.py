from sqlalchemy import text
import time
import logging

from app.database import SessionLocal
from app.telemetry.metrics import (
    clientes_consultados,
    clientes_no_encontrados,
    duracion_consulta_cliente
)


logger = logging.getLogger(__name__)


def get_cliente(cliente_id: int):

    inicio = time.perf_counter()

    try:

        logger.info(
            "Buscando cliente %s en la base de datos",
            cliente_id
        )

        with SessionLocal() as session:

            resultado = session.execute(
                text("""
                    SELECT
                        id_cliente,
                        nombre,
                        email
                    FROM clientes
                    WHERE id_cliente = :cliente_id
                """),
                {
                    "cliente_id": cliente_id
                }
            )

            row = resultado.fetchone()

            clientes_consultados.add(1)

            if row is None:

                logger.warning(
                    "Cliente %s no encontrado en la base de datos",
                    cliente_id
                )

                clientes_no_encontrados.add(
                    1,
                    {
                        "motivo": "cliente_no_encontrado"
                    }
                )

                return None

            logger.info(
                "Cliente %s encontrado correctamente",
                cliente_id
            )

            return {
                "id_cliente": row.id_cliente,
                "nombre": row.nombre,
                "email": row.email
            }

    except Exception:

        logger.exception(
            "Error consultando cliente %s en la base de datos",
            cliente_id
        )

        raise

    finally:

        duracion_ms = (
            time.perf_counter() - inicio
        ) * 1000

        duracion_consulta_cliente.record(
            duracion_ms
        )