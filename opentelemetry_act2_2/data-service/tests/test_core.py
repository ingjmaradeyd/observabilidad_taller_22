import sys
import unittest
from pathlib import Path


SERVICE_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVICE_ROOT))

from app.core import (  # noqa: E402
    ChaosInjected,
    DatabaseUnavailable,
    DeterministicChaos,
    IdempotencyConflict,
    OrderCommand,
    OrderService,
    OrderValidationError,
    StoredOrder,
)


VALID_ORDER = {
    "id_cliente": 1,
    "producto": "OBSERVABILITY-LAB",
    "cantidad": 2,
    "valor": 1500.0,
}


class RecordingRepository:
    def __init__(self):
        self.commands = []
        self.orders_by_key = {}
        self.operation_calls = 0

    def create_or_replay(self, command, idempotency_key):
        self.operation_calls += 1
        existing = self.orders_by_key.get(idempotency_key)
        if existing:
            fingerprint, order = existing
            return StoredOrder(fingerprint=fingerprint, order=order)

        self.commands.append(command)
        order = {
            "id_pedidos": 41,
            "id_cliente": command.id_cliente,
            "producto": command.producto,
            "cantidad": command.cantidad,
            "valor": command.valor,
        }
        self.orders_by_key[idempotency_key] = (command.fingerprint(), order)
        return StoredOrder(fingerprint=command.fingerprint(), order=order)


class UnavailableRepository:
    def create_or_replay(self, command, idempotency_key):
        raise DatabaseUnavailable("database operation failed")


class DataServiceCoreTests(unittest.TestCase):
    def test_contract_preserves_order_fields_and_rejects_invalid_values(self):
        command = OrderCommand.from_mapping(VALID_ORDER)

        self.assertEqual(command.as_dict(), VALID_ORDER)

        invalid_payloads = [
            {**VALID_ORDER, "id_cliente": 0},
            {**VALID_ORDER, "producto": "   "},
            {**VALID_ORDER, "cantidad": 0},
            {**VALID_ORDER, "valor": 0},
        ]
        for payload in invalid_payloads:
            with self.subTest(payload=payload):
                with self.assertRaises(OrderValidationError):
                    OrderCommand.from_mapping(payload)

    def test_create_returns_persisted_order(self):
        repository = RecordingRepository()
        service = OrderService(
            repository=repository,
            chaos=DeterministicChaos(enabled=False, error_rate=0.1),
        )

        result = service.create(
            OrderCommand.from_mapping(VALID_ORDER),
            idempotency_key="create-41",
        )

        self.assertEqual(result["id_pedidos"], 41)
        self.assertEqual(result["producto"], VALID_ORDER["producto"])
        self.assertEqual(len(repository.commands), 1)

    def test_database_failure_is_exposed_as_stable_dependency_error(self):
        service = OrderService(
            repository=UnavailableRepository(),
            chaos=DeterministicChaos(enabled=False, error_rate=0.1),
        )

        with self.assertRaises(DatabaseUnavailable) as raised:
            service.create(
                OrderCommand.from_mapping(VALID_ORDER),
                idempotency_key="database-failure",
            )

        self.assertEqual(raised.exception.code, "DATABASE_UNAVAILABLE")

    def test_ten_percent_chaos_is_every_tenth_creation_only(self):
        repository = RecordingRepository()
        service = OrderService(
            repository=repository,
            chaos=DeterministicChaos(enabled=True, error_rate=0.1),
        )

        outcomes = []
        for _ in range(20):
            try:
                service.create(
                    OrderCommand.from_mapping(VALID_ORDER),
                    idempotency_key=f"chaos-{len(outcomes) + 1}",
                )
                outcomes.append("created")
            except ChaosInjected as error:
                self.assertEqual(error.code, "CHAOS_INJECTED")
                outcomes.append("chaos")

        self.assertEqual(
            [index for index, outcome in enumerate(outcomes, start=1) if outcome == "chaos"],
            [10, 20],
        )
        self.assertEqual(len(repository.commands), 18)

    def test_same_idempotency_key_and_payload_returns_existing_order(self):
        repository = RecordingRepository()
        service = OrderService(
            repository=repository,
            chaos=DeterministicChaos(enabled=False, error_rate=0.1),
        )
        command = OrderCommand.from_mapping(VALID_ORDER)

        first = service.create(command, idempotency_key="order-retry-1")
        replay = service.create(command, idempotency_key="order-retry-1")

        self.assertEqual(replay, first)
        self.assertEqual(len(repository.commands), 1)

    def test_same_idempotency_key_with_different_payload_conflicts(self):
        repository = RecordingRepository()
        service = OrderService(
            repository=repository,
            chaos=DeterministicChaos(enabled=False, error_rate=0.1),
        )

        service.create(
            OrderCommand.from_mapping(VALID_ORDER),
            idempotency_key="order-conflict-1",
        )

        with self.assertRaises(IdempotencyConflict) as raised:
            service.create(
                OrderCommand.from_mapping({**VALID_ORDER, "cantidad": 3}),
                idempotency_key="order-conflict-1",
            )

        self.assertEqual(raised.exception.code, "IDEMPOTENCY_CONFLICT")
        self.assertEqual(len(repository.commands), 1)

    def test_each_complete_idempotent_path_uses_one_repository_operation(self):
        repository = RecordingRepository()
        service = OrderService(
            repository=repository,
            chaos=DeterministicChaos(enabled=False, error_rate=0.1),
        )
        command = OrderCommand.from_mapping(VALID_ORDER)

        service.create(command, idempotency_key="single-operation")
        self.assertEqual(repository.operation_calls, 1)

        service.create(command, idempotency_key="single-operation")
        self.assertEqual(repository.operation_calls, 2)

        with self.assertRaises(IdempotencyConflict):
            service.create(
                OrderCommand.from_mapping({**VALID_ORDER, "cantidad": 3}),
                idempotency_key="single-operation",
            )
        self.assertEqual(repository.operation_calls, 3)

    def test_non_finite_and_coercive_numbers_never_reach_repository(self):
        repository = RecordingRepository()
        service = OrderService(
            repository=repository,
            chaos=DeterministicChaos(enabled=False, error_rate=0.1),
        )
        invalid_values = [
            float("inf"),
            float("-inf"),
            float("nan"),
            10**1000,
            True,
            "1",
        ]

        for value in invalid_values:
            with self.subTest(value=value):
                with self.assertRaises(OrderValidationError):
                    service.create_from_mapping(
                        {**VALID_ORDER, "valor": value},
                        idempotency_key="invalid-number",
                    )

        self.assertEqual(repository.commands, [])


if __name__ == "__main__":
    unittest.main()
