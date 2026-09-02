import logging

from opentelemetry import trace
from opentelemetry.trace import SpanKind
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.core import (
    DatabaseUnavailable,
    OrderCommand,
    StoredOrder,
)
from app.database import SessionLocal


logger = logging.getLogger(__name__)
tracer = trace.get_tracer(__name__)


class SqlAlchemyOrderRepository:
    def ready(self) -> None:
        try:
            with tracer.start_as_current_span(
                "db.connection.check",
                kind=SpanKind.CLIENT,
                attributes={
                    "db.system.name": "postgresql",
                    "db.operation.name": "SELECT",
                },
            ):
                with SessionLocal() as session:
                    session.execute(text("SELECT 1"))
        except SQLAlchemyError as error:
            logger.warning(
                "Database readiness check failed",
                extra={"event_name": "database.readiness", "outcome": "failure"},
            )
            raise DatabaseUnavailable("database readiness check failed") from error

    def create_or_replay(
        self,
        command: OrderCommand,
        idempotency_key: str,
    ) -> StoredOrder:
        try:
            with tracer.start_as_current_span(
                "db.pedidos.create_or_replay",
                kind=SpanKind.CLIENT,
                attributes={
                    "db.system.name": "postgresql",
                    "db.operation.name": "INSERT",
                    "db.collection.name": "pedidos",
                },
            ):
                return self._persist(command, idempotency_key)
        except SQLAlchemyError as error:
            self._raise_database_unavailable(error)

    @classmethod
    def _persist(
        cls,
        command: OrderCommand,
        idempotency_key: str,
    ) -> StoredOrder:
        fingerprint = command.fingerprint()
        with SessionLocal() as session:
            result = session.execute(
                text(
                    """
                    INSERT INTO pedidos (
                        id_cliente,
                        producto,
                        cantidad,
                        valor,
                        idempotency_key,
                        request_fingerprint
                    )
                    VALUES (
                        :id_cliente,
                        :producto,
                        :cantidad,
                        :valor,
                        :idempotency_key,
                        :request_fingerprint
                    )
                    ON CONFLICT (idempotency_key) DO UPDATE
                    SET idempotency_key = EXCLUDED.idempotency_key
                    RETURNING
                        id_pedidos,
                        id_cliente,
                        producto,
                        cantidad,
                        valor,
                        request_fingerprint
                    """
                ),
                {
                    **command.as_dict(),
                    "idempotency_key": idempotency_key,
                    "request_fingerprint": fingerprint,
                },
            )
            order = result.fetchone()
            session.commit()
            return cls._to_stored_order(order)

    @classmethod
    def _to_stored_order(cls, row) -> StoredOrder:
        if row is None:
            raise DatabaseUnavailable("order persistence returned no row")
        return StoredOrder(
            fingerprint=row.request_fingerprint,
            order=cls._row_to_order(row),
        )

    @staticmethod
    def _row_to_order(row) -> dict[str, object]:
        return {
            "id_pedidos": row.id_pedidos,
            "id_cliente": row.id_cliente,
            "producto": row.producto,
            "cantidad": row.cantidad,
            "valor": float(row.valor),
        }

    @staticmethod
    def _raise_database_unavailable(error: SQLAlchemyError) -> None:
        logger.error(
            "Order persistence failed",
            extra={"event_name": "order.persistence", "outcome": "failure"},
        )
        raise DatabaseUnavailable("database operation failed") from error
