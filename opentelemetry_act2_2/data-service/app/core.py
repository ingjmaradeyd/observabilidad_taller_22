from __future__ import annotations

import hashlib
import json
import math
import threading
import time
from dataclasses import dataclass
from typing import Mapping, Protocol


class OrderValidationError(ValueError):
    code = "INVALID_ORDER"


class DatabaseUnavailable(RuntimeError):
    code = "DATABASE_UNAVAILABLE"


class ChaosInjected(RuntimeError):
    code = "CHAOS_INJECTED"


class IdempotencyConflict(RuntimeError):
    code = "IDEMPOTENCY_CONFLICT"


class InvalidIdempotencyKey(ValueError):
    code = "INVALID_IDEMPOTENCY_KEY"


def is_finite_json_number(value: object) -> bool:
    if type(value) not in {int, float}:
        return False
    try:
        return math.isfinite(float(value))
    except OverflowError:
        return False


@dataclass(frozen=True)
class OrderCommand:
    id_cliente: int
    producto: str
    cantidad: int
    valor: float

    @classmethod
    def from_mapping(cls, payload: Mapping[str, object]) -> "OrderCommand":
        required_fields = {"id_cliente", "producto", "cantidad", "valor"}
        if set(payload) != required_fields:
            raise OrderValidationError("order fields do not match the contract")

        customer_id = payload["id_cliente"]
        product = payload["producto"]
        quantity = payload["cantidad"]
        value = payload["valor"]

        if isinstance(customer_id, bool) or not isinstance(customer_id, int) or customer_id <= 0:
            raise OrderValidationError("id_cliente must be a positive integer")
        if not isinstance(product, str) or not product.strip():
            raise OrderValidationError("producto must not be blank")
        if isinstance(quantity, bool) or not isinstance(quantity, int) or quantity <= 0:
            raise OrderValidationError("cantidad must be a positive integer")
        if (
            not is_finite_json_number(value)
            or float(value) <= 0
        ):
            raise OrderValidationError("valor must be greater than zero")

        return cls(
            id_cliente=customer_id,
            producto=product.strip(),
            cantidad=quantity,
            valor=float(value),
        )

    def as_dict(self) -> dict[str, int | str | float]:
        return {
            "id_cliente": self.id_cliente,
            "producto": self.producto,
            "cantidad": self.cantidad,
            "valor": self.valor,
        }

    def fingerprint(self) -> str:
        canonical_payload = json.dumps(
            self.as_dict(),
            ensure_ascii=True,
            separators=(",", ":"),
            sort_keys=True,
        )
        return hashlib.sha256(canonical_payload.encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class StoredOrder:
    fingerprint: str
    order: dict[str, object]


class OrderRepository(Protocol):
    def create_or_replay(
        self,
        command: OrderCommand,
        idempotency_key: str,
    ) -> StoredOrder: ...


class OrderMetrics(Protocol):
    def record_created(self) -> None: ...

    def record_failure(self, reason: str) -> None: ...

    def record_duration(self, duration_ms: float) -> None: ...


class NullOrderMetrics:
    def record_created(self) -> None:
        pass

    def record_failure(self, reason: str) -> None:
        pass

    def record_duration(self, duration_ms: float) -> None:
        pass


class DeterministicChaos:
    def __init__(self, *, enabled: bool, error_rate: float) -> None:
        if not 0 <= error_rate <= 1:
            raise ValueError("error_rate must be between zero and one")

        self._enabled = enabled
        self._interval = round(1 / error_rate) if error_rate else None
        self._request_count = 0
        self._lock = threading.Lock()

    def should_inject(self) -> bool:
        if not self._enabled or self._interval is None:
            return False

        with self._lock:
            self._request_count += 1
            return self._request_count % self._interval == 0


class OrderService:
    def __init__(
        self,
        *,
        repository: OrderRepository,
        chaos: DeterministicChaos,
        metrics: OrderMetrics | None = None,
    ) -> None:
        self._repository = repository
        self._chaos = chaos
        self._metrics = metrics or NullOrderMetrics()

    def create_from_mapping(
        self,
        payload: Mapping[str, object],
        *,
        idempotency_key: str,
    ) -> dict[str, object]:
        command = OrderCommand.from_mapping(payload)
        return self.create(command, idempotency_key=idempotency_key)

    def create(
        self,
        command: OrderCommand,
        *,
        idempotency_key: str,
    ) -> dict[str, object]:
        started_at = time.perf_counter()
        try:
            key = self._validate_idempotency_key(idempotency_key)
            if self._chaos.should_inject():
                self._metrics.record_failure("chaos_injected")
                raise ChaosInjected("controlled failure injected")

            stored_order = self._repository.create_or_replay(command, key)
            if stored_order.fingerprint != command.fingerprint():
                self._metrics.record_failure("idempotency_conflict")
                raise IdempotencyConflict("key already used for another payload")

            self._metrics.record_created()
            return stored_order.order
        except DatabaseUnavailable:
            self._metrics.record_failure("database_unavailable")
            raise
        finally:
            duration_ms = (time.perf_counter() - started_at) * 1000
            self._metrics.record_duration(duration_ms)

    @staticmethod
    def _validate_idempotency_key(value: str) -> str:
        is_visible_ascii = all(32 <= ord(character) <= 126 for character in value)
        if (
            not value
            or len(value) > 128
            or value != value.strip()
            or not is_visible_ascii
        ):
            raise InvalidIdempotencyKey("idempotency key is invalid")
        return value
