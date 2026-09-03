# Laboratorio integrador de observabilidad en AWS

Este directorio contiene la infraestructura como código para la base AWS del laboratorio. La configuración está preparada para crear los recursos de forma reproducible, pero su presencia en Terraform **no demuestra que estén desplegados**.

## Arquitectura objetivo de esta unidad

- Una VPC con dos subredes públicas para ECS/Fargate y el ALB.
- Dos subredes privadas, sin ruta a Internet, para PostgreSQL RDS.
- Sin NAT Gateway ni VPC endpoints durante el laboratorio, para contener costos.
- Un ALB público que dirige tráfico exclusivamente a Service A.
- Service A, Service B y `data-service` en ECS/Fargate.
- ECS Service Connect en el namespace privado `${environment}.internal`:
  - Service A actúa como cliente.
  - Service B se descubre como `service-b:8001`.
  - `data-service` se descubre como `data-service:8002`.
- Service B y `data-service` no tienen listener, target group, URL pública ni ingreso desde Internet.
- Solo Service B y `data-service` acceden a RDS y reciben la contraseña administrada por Secrets Manager.
- Service A no recibe credenciales ni conectividad de red hacia RDS.
- CloudWatch Logs con retención de siete días para contenedores y proxies de Service Connect.

Las tareas usan subredes públicas y `assign_public_ip = true` únicamente para alcanzar ECR, CloudWatch y otros servicios de salida. Los grupos de seguridad continúan bloqueando el ingreso público directo. Esta es una optimización temporal para el sandbox académico, no una topología recomendada para producción.

## Estado de OpenTelemetry

En esta unidad, `OTEL_ENABLED=false` para los tres microservicios y `adot_desired_count=0`. Esto evita iniciar aplicaciones dependientes de ADOT antes de publicar las imágenes y completar la unidad de observabilidad. La configuración de Service Connect aporta descubrimiento y telemetría de red L7, pero no reemplaza la instrumentación OTel de aplicación.

ECS Service Connect sustituye a AWS App Mesh en este laboratorio porque App Mesh tiene anunciado su fin de soporte para el 30 de septiembre de 2026. La evidencia académica de esa sustitución deberá mostrar en AWS el namespace compartido, los servicios registrados, la comunicación por alias y los logs o métricas L7; el código por sí solo no demuestra la operación del mesh.

## Etiquetas de imagen obligatorias

Las cuatro imágenes usan repositorios ECR inmutables. Cada variable de etiqueta acepta únicamente:

- Un SHA Git corto en minúsculas, de 7 a 12 caracteres; o
- `v1.0.0` para la entrega final.

No se permiten etiquetas vacías ni `latest`:

```hcl
service_a_image_tag    = "abcdef1"
service_b_image_tag    = "abcdef1"
data_service_image_tag = "abcdef1"
adot_image_tag         = "abcdef1"
```

Todas las imágenes publicadas para estas tareas Fargate deben ser Linux x86_64. Desde la raíz del repositorio, se debe fijar la plataforma en cada construcción, sin depender de la arquitectura del host:

```bash
IMAGE_TAG=abcdef1

docker build --platform linux/amd64 -t "${SERVICE_A_REPOSITORY_URL}:${IMAGE_TAG}" opentelemetry_act2_2/servicio-a
docker push "${SERVICE_A_REPOSITORY_URL}:${IMAGE_TAG}"

docker build --platform linux/amd64 -t "${SERVICE_B_REPOSITORY_URL}:${IMAGE_TAG}" opentelemetry_act2_2/servicio-b
docker push "${SERVICE_B_REPOSITORY_URL}:${IMAGE_TAG}"

docker build --platform linux/amd64 -t "${DATA_SERVICE_REPOSITORY_URL}:${IMAGE_TAG}" opentelemetry_act2_2/data-service
docker push "${DATA_SERVICE_REPOSITORY_URL}:${IMAGE_TAG}"

docker build --platform linux/amd64 -t "${ADOT_REPOSITORY_URL}:${IMAGE_TAG}" opentelemetry_act2_2/observabilidad/aws
docker push "${ADOT_REPOSITORY_URL}:${IMAGE_TAG}"
```

Las variables `*_REPOSITORY_URL` representan las URLs ECR expuestas por los outputs de Terraform. La etiqueta debe coincidir con la declarada en el archivo `.tfvars` revisado.

## Bootstrap seguro

Todos los conteos deseados comienzan en cero porque los repositorios ECR estarán vacíos durante la primera creación:

```hcl
service_a_desired_count    = 0
service_b_desired_count    = 0
data_service_desired_count = 0
adot_desired_count         = 0
```

Secuencia prevista, siempre con revisión humana antes de aplicar:

1. Copiar `terraform.tfvars.example` a un archivo local `.tfvars` no versionado.
2. Ejecutar `terraform fmt -check -recursive` y `terraform validate`.
3. Revisar un `terraform plan` con los cuatro conteos en cero.
4. Aplicar solo después de aprobación explícita para crear VPC, ALB, RDS, ECR, ECS y los recursos auxiliares.
5. Construir con `--platform linux/amd64` y publicar las cuatro imágenes con la misma etiqueta inmutable declarada en variables.
6. Ejecutar la tarea one-shot de migración y validar el esquema de RDS antes de iniciar B o `data-service`.
7. Cambiar temporalmente a `1` los conteos de A, B y `data-service`, revisar otro plan y aplicar.
8. Habilitar ADOT y `OTEL_ENABLED` únicamente en la unidad posterior de observabilidad.
9. Recolectar evidencias sanitizadas y destruir los recursos al finalizar la demostración.

No se debe incrementar un conteo si su imagen no existe en ECR. Service A tampoco debe iniciarse hasta que B, `data-service` y el esquema requerido estén disponibles.

## Migración one-shot de RDS

Terraform crea la definición `rds-migrator`, pero **no crea un servicio ECS** ni ejecuta la migración automáticamente. La tarea reutiliza la imagen ya publicada de `data-service`, inyecta la contraseña administrada únicamente mediante el execution role y termina después de crear/actualizar de forma idempotente `clientes`, `pedidos`, `idempotency_key`, `request_fingerprint`, el índice único y el cliente semilla. No imprime credenciales ni SQL sensible.

Después de aplicar el plan aprobado y de publicar la imagen de `data-service` con la etiqueta configurada, ejecutá estos comandos desde `obsact22`:

```bash
CLUSTER_NAME="$(terraform output -raw ecs_cluster_name)"
TASK_DEFINITION="$(terraform output -raw rds_migrator_task_definition_arn)"
SECURITY_GROUP_ID="$(terraform output -raw rds_migrator_security_group_id)"
SUBNET_IDS="$(terraform output -json rds_migrator_subnet_ids | jq -r 'join(",")')"

TASK_ARN="$(aws ecs run-task \
  --cluster "$CLUSTER_NAME" \
  --launch-type FARGATE \
  --task-definition "$TASK_DEFINITION" \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
  --query 'tasks[0].taskArn' \
  --output text)"

test "$TASK_ARN" != "None"
aws ecs wait tasks-stopped --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN"
aws ecs describe-tasks \
  --cluster "$CLUSTER_NAME" \
  --tasks "$TASK_ARN" \
  --query 'tasks[0].{lastStatus:lastStatus,stoppedReason:stoppedReason,containers:containers[].{name:name,exitCode:exitCode,reason:reason}}'
```

Un estado `STOPPED` es normal para una tarea one-shot; el contenedor debe terminar con `exitCode: 0`. Validá también el mensaje de éxito, que solo aparece cuando las dos tablas, las dos columnas `NOT NULL`, el índice único y el cliente `id_cliente=1` fueron comprobados dentro de la misma transacción:

```bash
LOG_GROUP="$(terraform output -raw rds_migrator_log_group_name)"
TASK_ID="${TASK_ARN##*/}"
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name-prefix "ecs/rds-migrator/$TASK_ID" \
  --filter-pattern '"RDS schema migration and validation completed successfully."'
```

La tarea usa las mismas subredes públicas y `assignPublicIp=ENABLED` que los servicios del laboratorio únicamente para descargar la imagen y publicar logs. Su security group no tiene ingreso y solo permite salida DNS, HTTPS necesaria para AWS y PostgreSQL hacia RDS en el puerto 5432. En producción, reemplazá esta concesión temporal por subredes privadas con NAT o VPC endpoints.

## Variables principales

| Variable | Uso | Valor inicial |
|---|---|---:|
| `service_a_port` | Puerto público detrás del ALB | `8000` |
| `service_b_port` | Puerto privado de Service Connect | `8001` |
| `data_service_port` | Puerto privado de Service Connect | `8002` |
| `data_service_health_path` | Health check dentro del contenedor | `/health` |
| `data_service_cpu` | CPU Fargate de `data-service` | `256` |
| `data_service_memory` | Memoria Fargate de `data-service` | `512` MiB |
| `db_multi_az` | Alta disponibilidad de RDS | `false` |

## Validaciones y evidencia posterior

Antes de considerar funcional esta arquitectura se debe comprobar en AWS:

- El ALB solo contiene el target group de Service A.
- Service B y `data-service` no tienen rutas públicas.
- Los tres servicios muestran Service Connect habilitado en el mismo namespace.
- A resuelve `service-b:8001` y `data-service:8002`.
- RDS permanece privada y solo acepta conexiones desde los SG de B y data.
- A no contiene variables `DB_*` ni secretos de RDS.
- B y data obtienen la contraseña mediante el rol de ejecución autorizado, no mediante sus task roles.
- La creación de un pedido recorre A -> B -> data -> RDS.
- Los logs del proxy de Service Connect aparecen en el log group de retención limitada.

La infraestructura base ya está desplegada en AWS; hasta ejecutar estas comprobaciones, la unidad debe describirse como **desplegada parcialmente**, no como funcional end-to-end ni validada en producción simulada.
