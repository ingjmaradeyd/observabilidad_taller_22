# Laboratorio integrador de observabilidad en AWS

Implementación reproducible de una plataforma observable para una aplicación distribuida de pedidos. El proyecto integra OpenTelemetry, un collector ADOT, trazas distribuidas, métricas, logs, observabilidad de red, AWS AIOps y experimentos de caos controlados sobre AWS.

> **Alcance de la entrega:** la implementación y las pruebas finales se realizaron únicamente en AWS, en una cuenta de laboratorio. La solución no pretende desplegar una segunda versión en GCP.

## Resultado de la entrega

- Tres microservicios instrumentados: `service-a`, `service-b` y `data-service`.
- Despliegue en Amazon ECS con AWS Fargate.
- Persistencia en Amazon RDS for PostgreSQL.
- Enrutamiento externo mediante Application Load Balancer.
- Descubrimiento interno mediante AWS Cloud Map y ECS Service Connect.
- Exportación de telemetría mediante OpenTelemetry Collector/ADOT.
- Logs y métricas en Amazon CloudWatch y trazas con integración de AWS X-Ray.
- VPC Flow Logs y AWS Security Hub CSPM habilitados.
- Dos experimentos de caos ejecutados con recuperación documentada.
- Evidencias reproducibles y un informe técnico final en PDF.

## Arquitectura implementada

```text
Cliente
  │
  ▼
ALB ──► service-a ──► service-b ──► data-service ──► RDS PostgreSQL
          │               │                 │
          └───────────────┴─────────────────┴──► ADOT Collector
                                                       │
                              CloudWatch Logs/Metrics ◄─┴─► AWS X-Ray

ECS/Fargate + Cloud Map/Service Connect + VPC Flow Logs + Security Hub
```

Cada servicio emite señales OpenTelemetry. El collector ADOT recibe OTLP por gRPC, y los componentes de AWS almacenan o analizan las señales según el tipo de dato. La base de datos utiliza convenciones semánticas de OpenTelemetry para sus spans.

## Estructura del repositorio

| Ruta | Contenido |
|---|---|
| [`opentelemetry_act2_2/servicio-a`](opentelemetry_act2_2/servicio-a) | API de pedidos, orquestación del flujo y telemetría de `service-a`. |
| [`opentelemetry_act2_2/servicio-b`](opentelemetry_act2_2/servicio-b) | Consulta de clientes, acceso a PostgreSQL, telemetría y latencia de caos configurable. |
| [`opentelemetry_act2_2/data-service`](opentelemetry_act2_2/data-service) | Persistencia de pedidos, idempotencia, telemetría y error controlado configurable. |
| [`opentelemetry_act2_2/observabilidad`](opentelemetry_act2_2/observabilidad) | Docker Compose, collector local/ADOT, Prometheus, Loki y configuración de Grafana. |
| [`opentelemetry_act2_2/gameday`](opentelemetry_act2_2/gameday) | Scripts y configuración para pruebas locales de GameDay y caos. |
| [`obsact22`](obsact22) | Infraestructura AWS declarada con Terraform: red, ECS, ECR, RDS, ADOT, CloudWatch, AIOps, Flow Logs y seguridad. |
| [`benchmark/pedidos-k6.js`](benchmark/pedidos-k6.js) | Escenario de carga para validar el comportamiento del endpoint de pedidos. |
| [`scripts/aws`](scripts/aws) | Utilidades de auditoría y configuración de la cuenta de laboratorio. |
| [`tests`](tests) | Pruebas de los scripts de soporte AWS. |
| [`evidencias/laboratorio-integrador`](evidencias/laboratorio-integrador) | Evidencias AWS/locales y el documento final en PDF. |

## Ejecución resumida

### 1. Validar la infraestructura

Configurar credenciales temporales o un perfil IAM con permisos suficientes para la cuenta de laboratorio. No se incluyen credenciales, secretos ni archivos `terraform.tfvars` en el repositorio.

```bash
cd obsact22
cp terraform.tfvars.example terraform.tfvars
terraform fmt -recursive
terraform init
terraform validate
terraform plan
```

### 2. Construir y publicar imágenes

Construir las imágenes para la arquitectura de ejecución de Fargate, publicarlas en los repositorios ECR creados por Terraform y utilizar etiquetas inmutables. Después, actualizar las variables de imagen y aplicar la nueva revisión de las tareas ECS.

```bash
docker build --platform linux/amd64 -t <ECR_URL>:<TAG> <DIRECTORIO_DEL_SERVICIO>
docker push <ECR_URL>:<TAG>

cd obsact22
terraform plan -var="service_a_image_tag=<TAG>"
terraform apply -var="service_a_image_tag=<TAG>"
```

Repetir el proceso para `service-b`, `data-service` y el collector ADOT cuando corresponda. Los valores concretos de la cuenta y de la sesión se mantienen fuera del repositorio.

### 3. Verificar el flujo funcional

1. Confirmar que las tareas ECS estén `RUNNING` y saludables.
2. Consultar `GET /service-a/health` a través del ALB.
3. Ejecutar `POST /service-a/pedidos/crear` con un cliente válido.
4. Verificar el pedido en RDS y su trace distribuido.
5. Revisar logs, métricas, spans y alarmas en los servicios de observabilidad de AWS.

Para una ejecución local, se pueden levantar los servicios con los archivos Compose de [`opentelemetry_act2_2/observabilidad`](opentelemetry_act2_2/observabilidad) y consultar Jaeger, Grafana, Prometheus y Loki.

## Funcionalidades y resultados principales

| Área | Resultado observado |
|---|---|
| Flujo normal | Baseline de 30 solicitudes: 30 exitosas, disponibilidad del 100 % y p95 de 0.522669 s. |
| Trazabilidad | Un pedido generó spans encadenados en `service-a`, `service-b`, `data-service` y PostgreSQL. |
| Caos de latencia | `service-b` recibió una inyección controlada de 200 ms; la llamada directa observó aproximadamente 234 ms. |
| Caos de errores | `data-service` produjo 3 respuestas `503` en 30 solicitudes, equivalente a una tasa observada del 10 %. |
| AIOps | Un filtro de métricas y una alarma estática detectaron los 3 errores; el MTTD registrado fue 53.213 s. |
| Recuperación | La configuración de caos se retiró y el servicio volvió a la revisión estable documentada. |
| Red y seguridad | VPC Flow Logs registró tráfico `ACCEPT`/`REJECT`; Security Hub CSPM y sus estándares quedaron habilitados. |

## Índice de evidencias

Las evidencias originales se conservan como archivos de salida y capturas. El informe PDF incluye un anexo visual donde las evidencias textuales se presentan literalmente como imágenes para facilitar su revisión.

### AWS: despliegue y funcionamiento

- [Smoke test inicial](evidencias/laboratorio-integrador/aws/ecs/01-smoke-test.txt)
- [Flujo completo A → B → data-service → RDS](evidencias/laboratorio-integrador/aws/ecs/02-smoke-test-rds-20260903T031815Z.log)
- [Activación de OTel en ECS](evidencias/laboratorio-integrador/aws/ecs/03-otel-activation-status-success.txt)
- [Solicitud funcional con OTel](evidencias/laboratorio-integrador/aws/ecs/04-otel-smoke-request-20260903T033614Z.log)
- [Migración de esquema RDS](evidencias/laboratorio-integrador/aws/rds/01-rds-migrator-success.log)

### AWS: telemetría y trazas

- [Exportación OTel](evidencias/laboratorio-integrador/aws/observabilidad/01-exportacion-otel-20260903T033826Z.log)
- [Validación de red OTel](evidencias/laboratorio-integrador/aws/observabilidad/02-otel-network-apply-success.txt)
- [Flujo extremo a extremo](evidencias/laboratorio-integrador/aws/observabilidad/03-otel-e2e-20260903T040509Z.log)
- [Destino de trazas X-Ray activo](evidencias/laboratorio-integrador/aws/observabilidad/04-otel-xray-active-20260903T043329Z.log)

### AWS: Service Connect

- [Diagnóstico del proxy](evidencias/laboratorio-integrador/aws/service-connect/01-proxy-diagnostico-smoke-test.log)
- [Instancias registradas en Cloud Map](evidencias/laboratorio-integrador/aws/service-connect/02-cloudmap-registro-instances.txt)
- [Configuración ECS Service Connect](evidencias/laboratorio-integrador/aws/service-connect/03-ecs-service-connect-config.txt)
- [Conectividad validada desde ECS Exec](evidencias/laboratorio-integrador/aws/service-connect/04-ecs-exec-conectividad-service-b.png)

### AWS: caos y resiliencia

- [Baseline](evidencias/laboratorio-integrador/aws/chaos/00-baseline-20260903T050115Z.log)
- [Experimento de latencia en `service-b`](evidencias/laboratorio-integrador/aws/chaos/02-service-b-latency-20260903T054329Z.log)
- [Validación directa de latencia](evidencias/laboratorio-integrador/aws/chaos/03-service-b-direct-latency-cloudshell.log)
- [Experimento de error rate al 10 %](evidencias/laboratorio-integrador/aws/chaos/06-data-service-direct-ip-10pct-20260903T062008Z.log)
- [Rollback del experimento](evidencias/laboratorio-integrador/aws/chaos/07-chaos-rollback-20260903T062602Z.log)

### AWS: AIOps, red y seguridad

- [Configuración CloudWatch AIOps](evidencias/laboratorio-integrador/aws/aiops/01-aiops-cloudwatch-20260903T063731Z.log)
- [Ejecución de la carga de caos](evidencias/laboratorio-integrador/aws/aiops/02-aiops-chaos-20260903T064626Z.log)
- [Datapoint detectado por CloudWatch](evidencias/laboratorio-integrador/aws/aiops/03-aiops-cloudwatch-datapoint-20260903T064600Z.log)
- [Análisis SLO y error budget](evidencias/laboratorio-integrador/aws/aiops/04-slo-error-budget-analysis.md)
- [MTTD de la alarma](evidencias/laboratorio-integrador/aws/aiops/05-mttd-static-alarm-20260903T064719Z.log)
- [VPC Flow Logs](evidencias/laboratorio-integrador/aws/network/01-vpc-flow-logs-20260903T044925Z.log)
- [Estándares de Security Hub](evidencias/laboratorio-integrador/aws/security-hub/01-standards-ready.json)
- [Captura de Security Hub CSPM](evidencias/laboratorio-integrador/aws/security-hub/02-security-hub-cspm-standards.png)

### Evidencias locales y benchmarks

Los resultados JSON de k6 ubicados en [`evidencias/laboratorio-integrador/local/benchmark`](evidencias/laboratorio-integrador/local/benchmark) corresponden a ejecuciones locales de laboratorio. No deben interpretarse como mediciones del despliegue AWS.

- [Resultados k6 locales](evidencias/laboratorio-integrador/local/benchmark)
- [Traza distribuida local](evidencias/laboratorio-integrador/local/01-traza-distribuida-jaeger-pedido-9481.png)
- [Span PostgreSQL local](evidencias/laboratorio-integrador/local/02-span-postgresql-otel-data-service.png)

## Documento final y video

- **Informe final:** [Informe_Final_Laboratorio_Integrador_AWS.pdf](evidencias/laboratorio-integrador/INFORME_FINAL_LABORATORIO_INTEGRADOR_AWS.pdf)
- **Video de demostración:** `VIDEO_URL_PENDIENTE`

El video debe mostrar, en este orden, el estado saludable de ECS, una solicitud funcional, la traza distribuida, la inyección de latencia, la inyección de errores, la detección en CloudWatch y el rollback. Las capturas y salidas usadas en la demostración están referenciadas en el índice anterior.

## Limpieza de recursos temporales

La infraestructura se creó para una práctica controlada. Después de guardar las evidencias, revisar el estado de la cuenta y eliminar los recursos temporales únicamente si ya no son necesarios:

```bash
cd obsact22
terraform destroy
```

Antes de ejecutar `terraform destroy`, verificar que el estado corresponda exclusivamente a este laboratorio y conservar el PDF, las capturas y los logs de la entrega.
