import logging

from sqlalchemy import text

from app.database import SessionLocal


logger = logging.getLogger(__name__)


def crear_pedido_cliente(
    id_pedidos: int,
    id_cliente: int,
    producto: str,
    cantidad: int,
    valor: float
):

    logger.info(
        "Iniciando persistencia del pedido para cliente %s",
        id_cliente
    )

    try:

        with SessionLocal() as db:

            result = db.execute(
                text("""
                    INSERT INTO pedidos (
                        id_pedidos,
                        id_cliente,
                        producto,
                        cantidad,
                        valor
                    )
                    VALUES (
                        nextval('pedidos_id_pedidos_seq'),
                        :id_cliente,
                        :producto,
                        :cantidad,
                        :valor
                    )
                    RETURNING
                        id_pedidos,
                        id_cliente,
                        producto,
                        cantidad,
                        valor
                """),
                {
                    "id_pedidos": id_pedidos,
                    "id_cliente": id_cliente,
                    "producto": producto,
                    "cantidad": cantidad,
                    "valor": valor
                }
            )

            pedido = result.fetchone()

            db.commit()

            logger.info(
                "Pedido %s persistido correctamente",
                pedido.id_pedidos
            )

            return {
                "id_pedidos": pedido.id_pedidos,
                "id_cliente": pedido.id_cliente,
                "producto": pedido.producto,
                "cantidad": pedido.cantidad,
                "valor": float(pedido.valor)
            }

    except Exception:

        logger.exception(
            "Error persistiendo pedido para cliente %s",
            id_cliente
        )

        raise