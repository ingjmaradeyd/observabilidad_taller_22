CREATE TABLE IF NOT EXISTS clientes (
    id_cliente INTEGER PRIMARY KEY,
    nombre TEXT NOT NULL,
    email TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS pedidos (
    id_pedidos SERIAL PRIMARY KEY,
    id_cliente INTEGER NOT NULL,
    producto TEXT NOT NULL,
    cantidad INTEGER NOT NULL,
    valor NUMERIC NOT NULL,
    idempotency_key TEXT NOT NULL,
    request_fingerprint CHAR(64) NOT NULL
);

ALTER SEQUENCE pedidos_id_pedidos_seq
    OWNED BY pedidos.id_pedidos;

INSERT INTO clientes (id_cliente, nombre, email)
VALUES (1, 'Cliente Game Day', 'cliente1@gameday.local')
ON CONFLICT (id_cliente) DO NOTHING;
