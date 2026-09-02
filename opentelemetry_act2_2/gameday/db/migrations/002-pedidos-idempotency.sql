BEGIN;

ALTER TABLE pedidos
    ADD COLUMN IF NOT EXISTS idempotency_key TEXT;

ALTER TABLE pedidos
    ADD COLUMN IF NOT EXISTS request_fingerprint CHAR(64);

UPDATE pedidos
SET idempotency_key = 'legacy-' || id_pedidos
WHERE idempotency_key IS NULL;

UPDATE pedidos
SET request_fingerprint = repeat('0', 64)
WHERE request_fingerprint IS NULL;

ALTER TABLE pedidos
    ALTER COLUMN idempotency_key SET NOT NULL,
    ALTER COLUMN request_fingerprint SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS pedidos_idempotency_key_uq
    ON pedidos (idempotency_key);

COMMIT;
