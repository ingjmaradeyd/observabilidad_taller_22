resource "aws_ecs_task_definition" "rds_migrator" {
  family                   = "${local.name}-rds-migrator"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.data_service_cpu)
  memory                   = tostring(var.data_service_memory)
  execution_role_arn       = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name      = "rds-migrator"
      image     = "${aws_ecr_repository.data_service.repository_url}:${var.data_service_image_tag}"
      essential = true
      command = [
        "python",
        "-c",
        <<-PYTHON
import os
import psycopg

required = ("DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD")
missing = [name for name in required if not os.environ.get(name)]
if missing:
    raise RuntimeError(f"Missing required database settings: {', '.join(missing)}")

connection = psycopg.connect(
    host=os.environ["DB_HOST"],
    port=os.environ["DB_PORT"],
    dbname=os.environ["DB_NAME"],
    user=os.environ["DB_USER"],
    password=os.environ["DB_PASSWORD"],
    connect_timeout=10,
    sslmode="require",
)

statements = (
    """
    CREATE TABLE IF NOT EXISTS clientes (
      id_cliente INTEGER PRIMARY KEY,
      nombre TEXT NOT NULL,
      email TEXT NOT NULL
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS pedidos (
      id_pedidos BIGSERIAL PRIMARY KEY,
      id_cliente INTEGER NOT NULL,
      producto TEXT NOT NULL,
      cantidad INTEGER NOT NULL,
      valor NUMERIC NOT NULL
    )
    """,
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS idempotency_key TEXT",
    "ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS request_fingerprint CHAR(64)",
    "UPDATE pedidos SET idempotency_key = 'legacy-' || id_pedidos WHERE idempotency_key IS NULL",
    "UPDATE pedidos SET request_fingerprint = repeat('0', 64) WHERE request_fingerprint IS NULL",
    "ALTER TABLE pedidos ALTER COLUMN idempotency_key SET NOT NULL",
    "ALTER TABLE pedidos ALTER COLUMN request_fingerprint SET NOT NULL",
    "CREATE UNIQUE INDEX IF NOT EXISTS pedidos_idempotency_key_uq ON pedidos (idempotency_key)",
)

try:
    with connection:
        with connection.cursor() as cursor:
            for statement in statements:
                cursor.execute(statement)
            cursor.execute(
                """
                INSERT INTO clientes (id_cliente, nombre, email)
                VALUES (%s, %s, %s)
                ON CONFLICT (id_cliente) DO NOTHING
                """,
                (1, "Cliente Game Day", "cliente1@gameday.local"),
            )
            cursor.execute(
                """
                SELECT
                  to_regclass('public.clientes') IS NOT NULL
                  AND to_regclass('public.pedidos') IS NOT NULL
                  AND EXISTS (
                    SELECT 1
                    FROM information_schema.columns
                    WHERE table_schema = 'public'
                      AND table_name = 'pedidos'
                      AND column_name = 'idempotency_key'
                      AND is_nullable = 'NO'
                  )
                  AND EXISTS (
                    SELECT 1
                    FROM information_schema.columns
                    WHERE table_schema = 'public'
                      AND table_name = 'pedidos'
                      AND column_name = 'request_fingerprint'
                      AND is_nullable = 'NO'
                  )
                  AND EXISTS (
                    SELECT 1
                    FROM pg_index AS index_metadata
                    JOIN pg_class AS index_relation
                      ON index_relation.oid = index_metadata.indexrelid
                    JOIN pg_class AS table_relation
                      ON table_relation.oid = index_metadata.indrelid
                    JOIN pg_namespace AS table_namespace
                      ON table_namespace.oid = table_relation.relnamespace
                    JOIN pg_attribute AS indexed_column
                      ON indexed_column.attrelid = table_relation.oid
                     AND indexed_column.attnum = index_metadata.indkey[0]
                    WHERE table_namespace.nspname = 'public'
                      AND table_relation.relname = 'pedidos'
                      AND index_relation.relname = 'pedidos_idempotency_key_uq'
                      AND index_metadata.indisunique
                      AND index_metadata.indisvalid
                      AND index_metadata.indisready
                      AND index_metadata.indnkeyatts = 1
                      AND index_metadata.indpred IS NULL
                      AND indexed_column.attname = 'idempotency_key'
                  )
                  AND EXISTS (
                    SELECT 1
                    FROM clientes
                    WHERE id_cliente = 1
                  )
                """
            )
            if not cursor.fetchone()[0]:
                raise RuntimeError("RDS schema validation failed after migration")
    print("RDS schema migration and validation completed successfully.")
finally:
    connection.close()
PYTHON
      ]

      environment = [
        {
          name  = "DB_HOST"
          value = aws_db_instance.postgres.address
        },
        {
          name  = "DB_PORT"
          value = tostring(aws_db_instance.postgres.port)
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "DB_USER"
          value = var.db_username
        }
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_db_instance.postgres.master_user_secret[0].secret_arn}:password::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.rds_migrator.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}
