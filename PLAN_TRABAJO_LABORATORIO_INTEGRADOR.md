# Plan de trabajo - Laboratorio integrador de observabilidad

## Objetivo

Extender el laboratorio 2.2 hasta una solución observable desplegada exclusivamente en un sandbox AWS, con detección automática de anomalías, observabilidad de red y seguridad, dos experimentos de caos controlados y MTTD inferior a dos minutos. El avance se actualizará marcando cada actividad completada.

## Estado general

- Fase actual: Security Hub está habilitado en la cuenta AWS nueva y sus estándares están en `READY`; la topología Terraform completa ya fue aplicada (94 recursos creados), las cuatro imágenes están verificadas en ECR, la tarea migratoria RDS terminó con `exitCode=0`, A/B/data-service y ADOT están activos, y el flujo funcional/OTel ya tiene evidencia AWS. La instrumentación de métricas y el pipeline OTLP están configurados; VPC Flow Logs ya entrega registros `ACCEPT/REJECT` y tiene una alarma operativa. Ambos experimentos de caos fueron realizados; el de `data-service` produjo 3/30 errores controlados y la alarma estática AIOps detectó `DataServiceChaosErrors=3` con MTTD de 53,213 s. La alarma de anomalías permanece `OK` por historial insuficiente. El rollback fue aplicado y el equipo confirmó posteriormente que Service B y `data-service` quedaron `COMPLETED` y estables; el archivo 07 conserva solo una captura intermedia `IN_PROGRESS`. Faltan MTTD de anomalía dinámica, p99 durante caos, correlación p99/`trace_id`, comparación de ruido/accionabilidad, dashboard de seguridad, madurez y cierre de entrega.
- Alcance aprobado: **únicamente AWS**.
- Impacto aceptado: no se cumplirá literalmente el nivel Excelente de los criterios que exigen AWS y GCP.
- Próximo hito: realizar la revisión final del informe, preparar el commit/tag y efectuar la entrega sin afirmar brechas no demostradas.
- Rama base: `developer`.
- Commit remoto verificado: `3ce9dcbd0f963844a2216ee4b4deb7aef36228d0`.
- Repositorio: público y sincronizado con GitHub.
- Tag final `v1.0`: pendiente.
- Regla de seguridad: los experimentos se ejecutarán únicamente en recursos sandbox, nunca en recursos compartidos.

## Meta de evaluación

| Criterio | Puntaje Excelente | Condición necesaria |
|---|---:|---|
| Arquitectura observable completa | 1,25 | Tres microservicios con OTel, service mesh y correlación completa en AWS y GCP. |
| AIOps | 1,00 | Detección automática, correlación y evidencia cuantitativa. |
| Network & Security Observability | 1,00 | Observabilidad funcional en AWS y GCP con dashboards y alertas. |
| Chaos Engineering y MTTD | 1,00 | Dos experimentos, MTTD menor o igual a dos minutos y análisis de SLO/error budget. |
| Madurez y presentación técnica | 0,75 | Autoevaluación completa, roadmap accionable y demostración técnica en vivo. |
| **Total** | **5,00** | Cumplir y evidenciar todos los módulos. |

> **Decisión consciente:** el equipo utilizará únicamente AWS, aunque la rúbrica exija ambas nubes para Excelente. Bajo una lectura estricta, el descriptor “una cloud” limita Arquitectura a 0,75 y Network & Security en una cloud a 0,80; el puntaje final seguirá dependiendo de la evaluación docente.

## 1. Inventario verificado del trabajo existente

- [x] Repositorio público en GitHub y rama `developer` sincronizada.
- [x] Service A y Service B implementados en FastAPI.
- [x] Flujo existente: cliente -> ALB -> Service A -> Service B -> PostgreSQL.
- [x] Terraform base para AWS: VPC, ALB, Cloud Map, ECS/Fargate, ECR, RDS, Secrets Manager, IAM, security groups y ADOT.
- [x] Código local de trazas, métricas y logs con OpenTelemetry en A y B.
- [x] Instrumentación automática de FastAPI, HTTPX y SQLAlchemy.
- [x] Stack local con Jaeger, Prometheus, Loki y Grafana.
- [x] Overlay local de Game Day con PostgreSQL, A, B, k6 y `tc netem`.
- [x] Baseline local ejecutado: 8.121 requests, 0 % de errores y p95 de 175,477 ms.
- [x] Experimento anterior ejecutado: latencia A->B de `800 ms ±100 ms`, rollback y evidencia local.
- [x] Código del Game Day publicado en el commit `3ce9dcb`.

## 2. Matriz de brechas

| Dominio | Estado actual | Brecha para Excelente |
|---|---|---|
| Arquitectura AWS | Parcial | Terraform existe, pero no demuestra despliegue vigente; A/B y ADOT parten con conteos no funcionales y `OTEL_ENABLED=false`. |
| Arquitectura GCP | Fuera de alcance | Se acepta explícitamente la pérdida de puntaje asociada a no implementar la segunda nube. |
| Tercer microservicio | Implementado localmente y preparado en IaC | `data-service` tiene API, persistencia, pruebas e instrumentación local; falta desplegarlo contra RDS y conservar evidencia AWS. |
| Tres pilares OTel | Parcial | A/B/data-service tienen instrumentación de logs, métricas y trazas; AWS tiene OTel habilitado con ADOT activo y evidencia correlacionada en logs/trazas. El alcance sigue siendo únicamente AWS. |
| Service mesh/L7 | Implementado en IaC, no desplegado | ECS Service Connect está configurado para A/B/data con alias privados; faltan despliegue y evidencia operativa L7 en AWS. |
| AIOps | Parcial | Terraform fue aplicado; la métrica `DataServiceChaosErrors=3` y la alarma estática en `ALARM` evidencian detección de los tres errores controlados, con MTTD de 53,213 s. La alarma de anomalías queda `OK` por historial insuficiente. Faltan aprendizaje de la banda, MTTD de anomalía dinámica, AWS DevOps Guru, p99 frente al SLO, correlación con `trace_id` y comparación cuantitativa de ruido/accionabilidad. |
| Red | Parcial | VPC Flow Logs está activo, entrega streams recientes y registra tráfico `ACCEPT/REJECT`; falta el análisis explícito N-S/E-W/entre servicios y un dashboard. |
| Seguridad observable | Parcial | IAM, SG, cifrado, escaneo ECR y Security Hub existen; falta consolidar señales, findings/CVEs, alertas y dashboard operativo. |
| Chaos solicitado | Parcial alto | Los dos experimentos AWS fueron realizados; el de errores de `data-service` observó 10 % de fallos, el rollback fue aplicado y estable, y la alarma estática tuvo MTTD de 53,213 s. Faltan MTTD de anomalía dinámica, p99 durante caos, correlación `trace_id` y comparación de ruido/accionabilidad. |
| SRE | Parcial | La ventana de caos tuvo 90 % de disponibilidad, 10 % de errores y consumió diez veces el presupuesto del 1 %; el MTTD de la alarma estática fue 53,213 s. Faltan p99 durante caos, MTTD de anomalía dinámica y evaluación de accionabilidad. |
| Madurez | Ausente | Falta autoevaluación de ocho dominios y roadmap de tres meses. |
| Evidencia publicable | Parcial | Los resultados anteriores son locales e ignorados por Git; falta un paquete liviano y trazable de evidencias. |
| Entrega | Parcial | Repositorio público listo; faltan demostración técnica y tag `v1.0`. |

## 3. Fase 0 - Decisiones y preflight

- [x] Confirmar alcance únicamente AWS, aceptando que no se alcanzará el Excelente multicloud.
- [x] Registrar GCP y Cloud SQL como fuera de alcance por decisión del equipo.
- [x] Confirmar la cuenta sandbox educativa disponible en AWS.
- [x] Definir `us-east-1` como región AWS del laboratorio.
- [x] Verificar la disponibilidad regional de ECS, RDS, Cloud Map, VPC Flow Logs, Security Hub, DevOps Guru, CloudWatch y X-Ray en `us-east-1`.
- [x] Definir un presupuesto máximo de **USD 20** antes de crear recursos.
- [x] Aprobar umbrales de alerta de costos al **50 % (USD 10), 80 % (USD 16) y 100 % (USD 20)**.
- [x] Verificar acceso de lectura a AWS Budgets mediante `describe-budgets` (`EXIT_CODE=0`).
- [x] Confirmar que AWS Budgets no contiene presupuestos previos en el sandbox.
- [x] Aprobar el correo institucional como destino de las notificaciones de costos, sin almacenarlo en Git.
- [x] Aprobar un script portable para recrear el presupuesto sin almacenar correo, credenciales ni AccountId.
- [x] Implementar `scripts/aws/configure_cost_budget.sh` con preflight seguro y creación no destructiva.
- [x] Validar localmente el script con `bash -n`, `--help` y AWS CLI simulado para creación, presupuesto existente, error inesperado y privacidad de salida.
- [ ] Ejecutar el script con el perfil `observabilidad-lab` y configurar realmente el presupuesto y sus alertas en AWS. **Pospuesto por decisión del equipo; no bloquea el trabajo local de la actividad.**
- [ ] Confirmar en AWS la suscripción del correo institucional a las tres alertas de costos.
- [ ] Confirmar que ningún recurso sea compartido con otros ambientes.
- [x] Instalar y validar localmente AWS CLI `2.36.37` y Terraform `1.16.0` para `darwin_arm64`.
- [x] Configurar el perfil local `observabilidad-lab` y validar su identidad mediante AWS STS, sin almacenar secretos en Git.
- [ ] Verificar cuotas y permisos efectivos del sandbox.
- [x] Aprobar el diseño de una auditoría AWS de solo lectura, reproducible y sin creación de recursos.
- [x] Implementar y validar `scripts/aws/check_sandbox_capabilities.sh` usando únicamente operaciones `Get`, `List` y `Describe`.
- [ ] Ejecutar la auditoría con el perfil `observabilidad-lab` y conservar un resultado sanitizado como evidencia.
- [ ] Definir convención de nombres, etiquetas de costo y política de destrucción del sandbox.
- [x] Aprobar la topología temporal AWS sin NAT: tareas ECS en subredes públicas con IP pública solo para salida, ALB únicamente para A, B/data privados por SG y RDS en subredes privadas.
- [x] Documentar y aprobar la base AWS, sus límites de costo, bootstrap, validación y rollback antes de modificar Terraform.
- [ ] Registrar el estado inicial con `terraform validate`, plan reproducible e inventario de recursos existentes.

### Diseño aprobado de la auditoría del sandbox

- **Entrada:** perfil AWS `observabilidad-lab` y región `us-east-1`.
- **Cobertura:** STS, ECS/Service Connect, RDS, Cloud Map, VPC Flow Logs, Security Hub, DevOps Guru, CloudWatch Logs/Dashboards y X-Ray.
- **Seguridad:** no ejecutará operaciones de creación, modificación o eliminación, ni imprimirá claves, tokens o identificadores completos de la cuenta.
- **Salida:** tabla con estados `DISPONIBLE`, `NO HABILITADO`, `DENEGADO` o `ERROR`, apta para incorporarse como evidencia del informe.
- **Criterio de éxito:** distinguir disponibilidad regional de permisos efectivos y servicios aún no habilitados en el sandbox.

### Diseño portable del control operativo de costos

- **Automatización:** `scripts/aws/configure_cost_budget.sh` obtiene el AccountId mediante STS y usa el perfil `observabilidad-lab`, reemplazable con `--profile` para migrar a otra cuenta.
- **Presupuesto:** `observabilidad-lab-mensual`, tipo `COST`, límite de **USD 20** por período mensual.
- **Alertas:** gasto real al **50 %**, **80 %** y **100 %**, con un suscriptor `EMAIL` solicitado sin eco y nunca persistido por el script. Las invocaciones desvían la historia opcional de AWS CLI a `/dev/null` para evitar que registre el correo.
- **Reejecución segura:** consulta primero el presupuesto; si existe, muestra solamente su estado sanitizado y termina sin modificarlo. Los demás errores abortan la operación.
- **Evidencia:** después de crear, muestra nombre, límite, unidad, período y umbrales, sin correo ni AccountId.
- **Rollback:** es exclusivamente manual y está documentado en `--help`; el script nunca elimina recursos.
- **Estado:** diseño, implementación y pruebas locales completados; creación y confirmación de alertas en AWS pendientes.
- **Alcance:** facilita la portabilidad del sandbox, aunque no se presentará como cumplimiento directo de un criterio puntuable de la rúbrica.

**Criterio de salida:** alcance aprobado, sandbox aislado, presupuesto y permisos confirmados.

## 4. Fase 1 - Recuperar y estabilizar la base AWS

- [ ] Verificar qué recursos AWS existen actualmente; no usar `plan.txt` como evidencia de despliegue.
- [x] Aprobar el diseño IaC de ECR sin desplegar recursos.
- [x] Implementar el diseño IaC aprobado para los cuatro repositorios ECR.
- [x] Inicializar localmente el proveedor AWS y validar la configuración con `terraform fmt -check` y `terraform validate`, sin ejecutar `plan` ni `apply`.
- [x] Implementar en código la unidad 1 de red y seguridad: topología sin NAT/EIP ni subredes privadas de aplicación, tareas existentes en subredes públicas, ALB exclusivo para A y matriz de SG de mínimo privilegio para A, B, futuro `data-service` y RDS. **No se ejecutaron operaciones contra AWS.**
- [x] Validar localmente la unidad 1 con `terraform fmt -check -recursive`, `terraform validate` y `terraform graph -type=plan`.
- [x] Completar la revisión técnica independiente 4R de la unidad 1 y verificar la corrección del único hallazgo crítico.
- [x] Mantener `adot_desired_count = 0` durante el bootstrap para no iniciar una imagen inexistente antes de publicarla en ECR.
- [x] Implementar en Terraform la unidad 2: tarea y servicio ECS de `data-service`, Service Connect en A/B/data, alias privados estables y logs del proxy con retención de siete días.
- [x] Retirar el servicio Cloud Map y el `service_registries` independientes de Service B, conservando el namespace privado como namespace de Service Connect.
- [x] Mantener A/B/data/ADOT con conteo deseado cero y `OTEL_ENABLED=false` hasta publicar las imágenes y habilitar la observabilidad en su unidad correspondiente.
- [x] Actualizar `terraform.tfvars.example` y el README de IaC con etiquetas inmutables, bootstrap seguro, topología sin NAT y ausencia de exposición pública para B/data.
- [x] Validar localmente la unidad 2 con `terraform fmt -check -recursive`, `terraform validate`, `terraform graph -type=plan` y aserciones estáticas de arquitectura. No se ejecutaron `terraform plan`, `apply` ni llamadas a AWS.
- [x] Completar la revisión técnica independiente 4R de la unidad 2 y verificar la corrección de los dos hallazgos críticos confirmados: health check ECS de Service B y plataforma `LINUX/X86_64` alineada con builds `linux/amd64`.
- [x] Habilitar OTel para A, B y `data-service` cuando ADOT esté publicado y operativo; mantenerlo deshabilitado durante el bootstrap. Aplicado en AWS con ADOT activo.
- [x] Revisar y conservar en cero los conteos deseados de A, B, `data-service` y ADOT durante el bootstrap de ECR/RDS.
- [x] Crear los cuatro repositorios ECR mediante Terraform en la cuenta AWS nueva. El `apply` completo creó los repositorios; el bloqueo correspondía únicamente al sandbox anterior.
- [x] Publicar y verificar las cuatro imágenes versionadas en ECR con el tag inmutable `abcdef1` y plataforma `linux/amd64`; evitar depender de tags mutables o `latest`.
- [x] Implementar en Terraform una tarea ECS/Fargate migratoria one-shot, con security group dedicado, secreto RDS administrado y validación idempotente del esquema. Ejecutar y validar la tarea en AWS antes de activar B y `data-service`.
- [x] Revisar el plan incremental del migrador: `8 to add, 0 to change, 0 to destroy`; incluye únicamente log group, task definition y security group/reglas de red del migrador.
- [x] Aprobar explícitamente la aplicación del plan incremental de 8 recursos del migrador.
- [x] Confirmar en el estado Terraform la creación de los 8 recursos del migrador RDS.
- [x] Ejecutar la tarea migratoria one-shot en AWS y obtener `lastStatus=STOPPED` con `exitCode=0`; conservar todavía el log de éxito como evidencia.
- [x] Conservar el mensaje de éxito de la migración RDS en `evidencias/laboratorio-integrador/aws/rds/01-rds-migrator-success.log`.
- [x] Ejecutar validaciones de Terraform y documentar el plan antes de aplicar.
- [x] Revisar el alcance del plan Terraform reproducible de la cuenta nueva: `94 to add, 0 to change, 0 to destroy`; la suma fue verificada por tipo de recurso y corresponde a la topología AWS completa. No se ejecutó `apply`.
- [x] Aprobar explícitamente la aplicación del plan completo de 94 recursos en la cuenta AWS nueva.
- [x] Aplicar el plan Terraform completo en la cuenta AWS nueva: `94 added, 0 changed, 0 destroyed`.
- [x] Revisar el plan de activación ECS: `0 to add, 3 to change, 0 to destroy`; únicamente `desired_count` cambia de `0` a `1` en A, B y `data-service`.
- [x] Aprobar explícitamente la activación de una tarea para A, B y `data-service`.
- [x] Aplicar la activación ECS: `0 added, 3 changed, 0 destroyed`.
- [x] Activar A, B y `data-service` con una tarea cada uno; la salud y el flujo de negocio siguen pendientes de verificación.
- [x] Verificar en ECS A, B y `data-service` con `desired=1`, `running=1`, `pending=0` y estado `ACTIVE`.
- [x] Ejecutar smoke test A→B→data-service→RDS. El primer intento devolvió `503 SERVICE_B_UNAVAILABLE`; después de verificar Service Connect, el reintento del `2026-09-03T03:18:15Z` respondió `/health` HTTP 200 y creó `id_pedidos=1` con HTTP 200. Evidencia: `evidencias/laboratorio-integrador/aws/ecs/02-smoke-test-rds-20260903T031815Z.log`.
- [x] Conservar logs del proxy Service Connect del incidente: `evidencias/laboratorio-integrador/aws/service-connect/01-proxy-diagnostico-smoke-test.log`; muestran reinicios de Envoy y timeout inicial de endpoints, sin evidencia todavía de causa raíz definitiva.
- [x] Desplegar la base AWS en sandbox y ejecutar smoke tests A->B->RDS; la línea base final respondió HTTP 200 y creó el pedido `id_pedidos=1`.
- [x] Activar ADOT (`adot_desired_count=1`) y `OTEL_ENABLED=true` en A, B y `data-service`; Terraform aplicó `3 added, 4 changed, 3 destroyed` y los cuatro servicios quedaron con `desired=1`, `running=1`, `pending=0`, `ACTIVE`. Evidencia: `evidencias/laboratorio-integrador/aws/ecs/03-otel-activation-status-success.txt`.
- [x] Corregir las reglas de security groups para permitir OTLP/gRPC TCP 4317 entre A/B/data-service y ADOT, usando referencias entre security groups.
- [x] Aplicar la corrección de red OTLP: Terraform aplicó `4 added, 0 changed, 0 destroyed` (reglas SG TCP 4317 para A/B/data-service ↔ ADOT). La verificación de recepción/exportación queda en la siguiente actividad.
- [x] Verificar exportación real de logs y trazas al backend elegido. La evidencia final confirma `CloudWatchLogs`/X-Ray en estado `ACTIVE`, una petición A→B→data-service→RDS con HTTP 200 y spans en `aws/spans` correlacionados entre los tres servicios mediante un mismo `traceId` (`evidencias/laboratorio-integrador/aws/observabilidad/04-otel-xray-active-20260903T043329Z.log`). Los errores HTTP 400 del archivo 03 son históricos, anteriores al cambio de destino.
- [x] Mantener instrumentación de métricas OTel en A, B y `data-service` y su pipeline OTLP hacia CloudWatch (`opentelemetry_act2_2/observabilidad/aws/otel-collector-config-aws.yaml`). La evidencia principal de correlación AWS se conserva en logs y trazas.
- [ ] Documentar endpoints, IDs de despliegue y evidencia mínima sin exponer secretos.

### Diseño aprobado de ECR

- **Repositorios:** `service-a`, `service-b`, `data-service` y `adot-collector` administrados por Terraform.
- **Escaneo:** ECR Basic Scanning con `scan_on_push = true` en cada repositorio.
- **Versionado:** tags de imagen explícitos e inmutables; no depender de `latest`.
- **Trazabilidad:** nombres y etiquetas coherentes con el ambiente y componente.
- **Evidencia posterior:** configuración `scanOnPush`, resultado del escaneo y conteo de CVEs por severidad sin publicar identificadores sensibles.
- **Límite actual:** el código y el plan de cuatro repositorios fueron revisados. La creación queda pendiente de aplicar el plan completo en la cuenta AWS nueva; no se utilizarán repositorios preprovisionados.

**Criterio de salida:** A y B funcionan en AWS con telemetría correlacionada y despliegue reproducible.

> **Control de esta unidad:** `terraform fmt -check -recursive`, `terraform validate` y `terraform graph -type=plan` finalizaron correctamente. La revisión independiente 4R no encontró bloqueadores; detectó un hallazgo crítico de bootstrap ADOT, corregido al dejar su conteo deseado en cero y verificado mediante revisión focalizada. Permanecen observaciones informativas de documentación, etiquetas y artefactos históricos para una unidad posterior. No se ejecutaron `plan`, `apply` ni operaciones contra AWS.

> **Control de la unidad 2:** la revisión independiente 4R identificó dos hallazgos críticos y tres verificadores por separado confirmaron ambos. Service B recibió un health check de contenedor sobre `/health`; A, B, `data-service` y ADOT fijan `LINUX/X86_64`, y el flujo documentado de construcción fija `linux/amd64`. Una re-revisión acotada verificó ambas correcciones. Los checks del implementador (`terraform fmt -check -recursive`, `terraform validate` y `git diff --check`) finalizaron correctamente. No se ejecutaron `terraform plan`, `apply`, builds, pushes ni llamadas a AWS.

## 5. Fase 2 - Arquitectura observable de tres servicios en AWS

- [x] Aprobar `data-service` como propietario de la persistencia de pedidos; Service A dejará de escribir directamente en RDS.
- [x] Diseñar y aprobar el contrato mínimo de `data-service` antes de implementarlo.
- [x] Implementar `data-service` con health check y manejo explícito de errores.
- [x] Instrumentar data-service con logs, métricas y trazas OTel.
- [x] Incorporar spans de PostgreSQL con OTel DB Semantic Conventions y atributos no sensibles.
- [x] Exigir `Idempotency-Key` en Service A y `data-service`, persistirlo de forma única y rechazar reutilización con otro payload mediante `409 IDEMPOTENCY_CONFLICT`.
- [x] Resolver creación/repetición/conflicto con un único statement idempotente y acotar el request DB completo por debajo del timeout HTTP de cinco segundos de Service A; mantener `/health` fuera del pool síncrono.
- [x] Rechazar booleanos, coerciones y valores numéricos no finitos antes de persistir pedidos.
- [x] Restringir la publicación local de `data-service:8002` a `127.0.0.1` en el Compose Game Day.
- [x] Verificar Docker Desktop `28.0.4` disponible en la terminal del equipo para ejecutar el smoke test local.
- [x] Validar el modelo Compose combinado (`docker-compose.yml` + override `docker-compose.gameday.yml`) con el proyecto `observabilidad`.
- [x] Confirmar el stack Compose previo en ejecución con PostgreSQL, A, B, ADOT, Jaeger, Prometheus, Loki y Grafana antes de incorporar `data-service`.
- [x] Construir e iniciar `data-service` mediante el modelo Compose combinado, con publicación exclusiva en `127.0.0.1:8002`.
- [x] Confirmar que `data-service` alcanza estado `healthy` y que `/health` y `/ready` responden HTTP `200`.
- [x] Reconstruir `service-a` con la integración hacia `data-service` y confirmar su estado `healthy` y `/health` con HTTP `200`.
- [x] Ejecutar una creación exitosa por Service A con cliente existente y recibir el pedido `9481` con HTTP `200`.
- [x] Verificar que el pedido `9481` fue persistido por `data-service` con la misma `Idempotency-Key` y una huella de 64 caracteres.
- [x] Confirmar que Jaeger registra `servicio-a`, `servicio-b` y `data-service` como fuentes de telemetría.
- [x] Localizar la traza distribuida A -> B -> `data-service` -> PostgreSQL bajo un único `trace_id`.
- [x] Guardar la captura general de Jaeger para la traza `ee60f8cb38e8b7e5938c133e3a586fad`, con `Services 3`, 18 spans y la cascada completa.
- [x] Guardar una captura detallada del span `db.pedidos.create_or_replay` con `db.system.name=postgresql`, `db.operation.name=INSERT` y `db.collection.name=pedidos` visibles.
- [x] Verificar que la tabla `pedidos` existe en el volumen PostgreSQL anterior y todavía no contiene `idempotency_key` ni `request_fingerprint`.
- [x] Ejecutar explícitamente la migración idempotente `002-pedidos-idempotency.sql` sobre el volumen PostgreSQL existente antes del smoke test.
- [x] Verificar el esquema posmigración: columnas `NOT NULL`, índice único y ausencia de valores nulos.
- [x] Conectar realmente `data-service` a AWS RDS mediante secretos administrados y conservar evidencia de la prueba. El smoke test AWS creó `id_pedidos=1` con HTTP 200 a través de A→B→data-service→RDS (`evidencias/laboratorio-integrador/aws/ecs/02-smoke-test-rds-20260903T031815Z.log`).
- [x] Implementar la migración one-shot de RDS como task definition ECS/Fargate, usando la imagen existente de `data-service`, secret injection por execution role, un security group dedicado y logs de CloudWatch.
- [ ] Ejecutar la tarea one-shot en AWS y conservar la salida sanitizada que confirma tablas `clientes`/`pedidos`, columnas de idempotencia, índice único y cliente semilla.
- [x] Configurar en Terraform el endpoint, usuario y secreto administrado de RDS para `data-service`, utilizando el rol de ejecución autorizado y sin permiso de secreto en el task role.
- [x] Definir en Terraform conectividad restringida para que `data-service` acceda a RDS sin exponer la base públicamente.
- [x] Aprobar ECS Service Connect como reemplazo técnico de AWS App Mesh por su fin de soporte anunciado.
- [x] Implementar en Terraform ECS Service Connect para A, B y `data-service`, con A como cliente y alias `service-b:8001` y `data-service:8002`. La operación real en AWS sigue pendiente.
- [x] Verificar en AWS el namespace y el registro saludable de `service-b` y `data-service` en Cloud Map; cada uno tiene una instancia activa con IP/puerto (`evidencias/laboratorio-integrador/aws/service-connect/02-cloudmap-registro-instances.txt`).
- [x] Verificar en AWS la configuración efectiva de Service Connect en la revisión ECS: `enabled=true`, namespace correcto y alias `service-b:8001` (`evidencias/laboratorio-integrador/aws/service-connect/03-ecs-service-connect-config.txt`).
- [x] Verificar desde una tarea de `service-a` la resolución del alias `service-b` y la conectividad HTTP a `http://service-b:8001/clientes/1`; la captura quedó en `evidencias/laboratorio-integrador/aws/service-connect/04-ecs-exec-conectividad-service-b.png`. Los logs L7 y la correlación de traza AWS siguen pendientes.
- [x] Preparar temporalmente ECS Exec solo para `service-a` y agregar permisos `ssmmessages` a su task role dedicado (`obsact22/ecs.tf`, `obsact22/iam.tf`).
- [x] Aplicar la revisión ECS de diagnóstico: política `ssmmessages` creada y `enable_execute_command=true` en `service-a` (`1 added, 1 changed, 0 destroyed`).
- [x] Forzar un nuevo deployment de `service-a` y verificar la tarea nueva: `enableExecuteCommand=true`, estado `HEALTHY` y `ExecuteCommandAgent=RUNNING`.
- [ ] Retirar ECS Exec temporal de `service-a` después de completar el diagnóstico.
- [x] Documentar la sustitución de App Mesh por Service Connect y distinguir el código preparado de la evidencia operativa aún pendiente.
- [ ] Capturar evidencia L7 y correlación de `trace_id` a través de los tres servicios en AWS.

### Validación de esta fase contra la rúbrica

| Exigencia | Cobertura del diseño aprobado | Evidencia todavía requerida |
|---|---|---|
| Tres microservicios instrumentados | A consulta clientes en B y delega la creación de pedidos a `data-service`. | Despliegue funcional y captura de una traza que atraviese A, B, `data-service` y RDS. |
| Tres pilares OpenTelemetry | `data-service` replicará el patrón OTel de A y B para logs, métricas y trazas. | Telemetría exportada y correlacionada en AWS; no basta con mostrar código. |
| Spans de base de datos | Solo B y `data-service` accederán a sus tablas en RDS mediante SQLAlchemy instrumentado. | Spans con convenciones semánticas DB y sin consultas ni datos sensibles. |
| Observabilidad de red L7 | Se utilizará ECS Service Connect como sustitución documentada de App Mesh. | Métricas/conectividad L7 y justificación técnica frente al texto literal de la actividad. |
| Error del 10 % en `data-service` | La inyección controlada afectará únicamente la creación de pedidos. | Ejecución real, alerta en menos de dos minutos y análisis de SLO/error budget. |

**Límite de calificación:** al trabajar únicamente en AWS, esta fase no puede demostrar el requisito literal de “ambas nubes”. Bajo lectura estricta, Arquitectura Observable queda limitada a **0,75/1,25**, aunque implementemos los tres servicios y toda la observabilidad en AWS.

### Diseño aprobado de `data-service`

- **Responsabilidad:** crear y persistir pedidos; Service A conserva la orquestación y Service B la consulta de clientes.
- **Flujo:** Service A valida `id_cliente` mediante Service B y, si existe, invoca `POST /pedidos` en `data-service`.
- **Contrato de entrada:** conservar los campos actuales `id_cliente`, `producto`, `cantidad` y `valor`, evitando cambios innecesarios al contrato público de Service A.
- **Idempotencia:** exigir `Idempotency-Key` en ambos endpoints de creación y reenviarlo sin cambios; la clave y la huella canónica del payload se persisten con índice único. Una repetición idéntica devuelve el pedido existente y una reutilización con otro payload responde `409 IDEMPOTENCY_CONFLICT`.
- **Endpoints:** `GET /health` para liveness, `GET /ready` para conectividad RDS y `POST /pedidos` para creación.
- **Respuestas:** `201` al crear o recuperar una repetición idempotente, `409 IDEMPOTENCY_CONFLICT`, `422` para entrada o clave inválida y `503` con código estable para RDS no disponible o caos inyectado.
- **Persistencia:** `data-service` será propietario lógico de la tabla `pedidos`; compartirá la instancia RDS del laboratorio para contener costos.
- **Resiliencia DB:** creación, repetición y conflicto se resuelven con un único `INSERT ... ON CONFLICT ... RETURNING`, sin lectura previa. El presupuesto conservador del request completo es 4,25 segundos (`pool` 0,25 s + conexión 1 s + statement 1,5 s + commit 1,5 s); `lock_timeout` de 500 ms queda incluido dentro del límite del statement. Se mantiene un pool de cuatro conexiones sin overflow y liveness asíncrono sin acceso a DB.
- **Validación numérica:** no aceptar coerción desde strings/booleanos ni `NaN`/infinito antes de invocar el repositorio.
- **Observabilidad:** logs estructurados, métricas y trazas OTel; spans PostgreSQL sin datos sensibles y propagación de `trace_id` desde Service A.
- **Caos:** inyección deshabilitada por defecto y configurable al 10 %; nunca afectará `/health` ni `/ready`.
- **Pruebas mínimas:** validación del contrato, creación exitosa, dependencia RDS fallida, inyección controlada y propagación de contexto.
- **Fuera de alcance:** CRUD adicional, inventario, exposición pública directa y una base de datos independiente.

**Validación local implementada (2026-09-02):** `data-service`, la delegación A -> `data-service`, el 404 real de Service B frente a fallos de dependencia, la propagación explícita de contexto, la idempotencia, los límites DB, el rechazo numérico previo al repositorio, el bind localhost y el caos determinista cada décima creación tienen pruebas unitarias/estáticas locales. La migración idempotente `002-pedidos-idempotency.sql` se ejecutó correctamente sobre el volumen existente (`BEGIN`/`COMMIT`) y completó las dos actualizaciones de 9.480 filas. La verificación posmigración confirmó ambas columnas como `NOT NULL`, el índice único `pedidos_idempotency_key_uq`, 9.480 filas conservadas y cero filas con valores nulos. `data-service` fue construido e iniciado mediante Compose; Docker lo reportó `healthy`, `/health` respondió `UP` con HTTP `200` y `/ready` respondió `READY` con HTTP `200`. Service A y Service B también fueron reconstruidos; ambos quedaron saludables y `/health` de Service A respondió HTTP `200`. Una solicitud real a Service A para el cliente `1` devolvió el pedido `9481` con HTTP `200`; PostgreSQL confirmó el mismo pedido, la clave `smoke-local-20260902T181840Z` y una huella de 64 caracteres. Jaeger registra telemetría de `servicio-a`, `servicio-b` y `data-service`. La traza `ee60f8cb38e8b7e5938c133e3a586fad` correlaciona los tres servicios e incluye spans PostgreSQL para la consulta del cliente y `db.pedidos.create_or_replay`. La captura general quedó guardada en `evidencias/laboratorio-integrador/local/01-traza-distribuida-jaeger-pedido-9481.png`; el detalle semántico del span DB quedó en `evidencias/laboratorio-integrador/local/02-span-postgresql-otel-data-service.png`. Esta validación local no constituye evidencia AWS, RDS real, Service Connect ni un experimento de caos ejecutado.

**Criterio de salida:** tres microservicios observables en AWS, RDS privado y evidencia funcional de service mesh/correlación.

## 6. Fase 3 - SLI, SLO y error budget

- [x] Definir SLIs de disponibilidad, `error_rate`, latencia p99 y throughput.
- [x] Aprobar SLO y ventana de medición antes de configurar alertas o caos.
- [x] Definir fórmula y presupuesto de error para la ventana seleccionada.
- [x] Ejecutar baseline controlado y calcular media, desviación estándar y percentiles.
- [x] Persistir un resumen reproducible del baseline sin subir archivos masivos (`evidencias/laboratorio-integrador/aws/chaos/00-baseline-20260903T050115Z.log`).

**Baseline AWS registrado:** 30 solicitudes, disponibilidad 100 %, `error_rate` 0 %, latencia media 280,704 ms, desviación estándar 82,183 ms, p95 522,669 ms y p99 estimado por nearest-rank (máximo de la muestra) 573,979 ms.

**SLO aprobado:** ventana de cinco minutos; disponibilidad ≥99 %, `error_rate` ≤1 % y latencia p99 ≤750 ms. El throughput se medirá como solicitudes completadas por minuto. El error budget de disponibilidad/error es el 1 % de las solicitudes de la ventana; una alerta de caos debe registrar el consumo observado frente a ese presupuesto.

**Criterio de salida:** baseline cuantitativo, SLO y error budget utilizables por AIOps y chaos.

## 7. Fase 4 - AIOps y correlación

- [ ] Configurar AWS DevOps Guru como servicio administrado de detección.
- [x] Implementar y aplicar la detección de errores controlados de `data-service`, con una métrica derivada de logs y una alarma estática de control. La evidencia registra `DataServiceChaosErrors=3` y la alarma estática en `ALARM` (`evidencias/laboratorio-integrador/aws/aiops/03-aiops-cloudwatch-datapoint-20260903T064600Z.log`).
- [x] Implementar y aplicar la condición dinámica con `ANOMALY_DETECTION_BAND(..., 2)` sobre la métrica de errores controlados. La alarma permanece `OK` por historial insuficiente; el aprendizaje de CloudWatch sigue pendiente (`evidencias/laboratorio-integrador/aws/aiops/03-aiops-cloudwatch-datapoint-20260903T064600Z.log`).
- [ ] Combinarla con `latency_p99 > SLO_threshold`.
- [ ] Enriquecer la alerta con el `trace_id` de una solicitud fallida.
- [x] Crear una alerta estática equivalente como grupo de control (`otel-fargate-lab-lab-data-service-chaos-errors-static`).
- [ ] Ejecutar una prueba repetible y medir alertas totales, falsas/ruidosas y accionables en ambos enfoques.
- [ ] Documentar cuantitativamente la reducción de ruido.

**Pendiente operativo de AIOps:** esperar el aprendizaje de la banda de anomalías y medir su MTTD; demostrar p99 frente al SLO, correlacionar una alerta con `trace_id`, ejecutar el grupo de control y comparar cuantitativamente ruido/accionabilidad. AWS DevOps Guru no está implementado.

**Criterio de salida:** anomalía detectada, alerta correlacionada con trace ID y comparación cuantitativa contra umbrales estáticos.

## 8. Fase 5 - Network & Security Observability

- [x] Habilitar VPC Flow Logs en AWS mediante Terraform y verificar delivery/consulta básica (`evidencias/laboratorio-integrador/aws/network/01-vpc-flow-logs-20260903T044925Z.log`).
- [x] Diseñar e implementar en Terraform la unidad de VPC Flow Logs: log group dedicado con retención de tres días, rol IAM mínimo, tráfico `ALL`, agregación de 60 segundos, métrica y alarma para `REJECT` (`obsact22/vpc_flow_logs.tf`).
- [ ] Definir consultas o métricas para tráfico Norte-Sur, Este-Oeste y entre servicios.
- [ ] Configurar alertas ante tráfico anómalo o conexiones no esperadas.
- [x] Aplicar la unidad IaC de Flow Logs en AWS; el delivery quedó `ACTIVE`, con streams recientes y registros `ACCEPT/REJECT` en la evidencia de red.
- [ ] Ejecutar consultas categorizadas y conservar evidencias específicas de tráfico Norte-Sur, Este-Oeste y entre servicios.
- [x] Evaluar Security Hub como opción de referencia para la arquitectura de seguridad.
- [x] Aprobar ECR Basic Scanning + VPC Flow Logs + CloudWatch como experimento de arquitectura directa para analizar sus beneficios.
- [x] Verificar ECR en el sandbox anterior: escaneo `BASIC`, sin reglas globales y sin repositorios existentes.
- [x] Habilitar AWS Security Hub en la cuenta nueva, región `us-east-1`.
- [x] Habilitar Security Hub v2 y confirmar sus tres recorders internos: assets, assets global y CSPM.
- [x] Verificar que los estándares AWS Foundational Security Best Practices v1.0.0 y CIS AWS Foundations Benchmark v1.2.0 quedaron en estado `READY`.
- [x] Conservar captura de consola de Security Hub CSPM con ambos estándares visibles (`evidencias/laboratorio-integrador/aws/security-hub/02-security-hub-cspm-standards.png`).
- [x] Conservar la salida CLI sanitizada de estándares `READY` (`evidencias/laboratorio-integrador/aws/security-hub/01-standards-ready.json`).
- [ ] Implementar ECR Basic Scanning y publicar métricas de CVEs activos en CloudWatch.
- [ ] Definir una señal controlada de intentos de autenticación fallidos.
- [ ] Integrar hallazgos de CVEs activos desde ECR/servicio de seguridad.
- [ ] Construir el dashboard “Golden Signals de Seguridad”.
- [ ] Validar que el dashboard muestre autenticación fallida, tráfico N-S/E-W y CVEs activos.

**Criterio de salida:** observabilidad de red y seguridad funcionales en AWS, con dashboard y alertas.

## 9. Fase 6 - Dos experimentos de caos y validación de MTTD

- [ ] Crear plan de Game Day específico para el sandbox cloud.
- [ ] Definir condiciones de aborto, blast radius, duración y rollback de ambos experimentos.
- [x] Experimento 1: inyectar 200 ms de latencia en Service B; llamada directa desde Service A devolvió HTTP 200 en 234 ms (`evidencias/laboratorio-integrador/aws/chaos/03-service-b-direct-latency-cloudshell.log`).
- [x] Implementar en Terraform la configuración del experimento 2 en `data-service`, con inyección deshabilitada por defecto y tasa de error configurable.
- [x] Experimento 2: inyectar 10 % de errores en data-service; 30 llamadas directas produjeron 27 HTTP 201 y 3 HTTP 503 `CHAOS_INJECTED` (10 % observado) (`evidencias/laboratorio-integrador/aws/chaos/06-data-service-direct-ip-10pct-20260903T062008Z.log`).
- [x] Capturar timestamp de inicio de cada inyección (`20260903T062008Z` para el experimento 2).
- [x] Capturar timestamp de detección y emisión de la alarma estática: transición `OK_TO_ALARM` en `20260903T064719.213Z` (`evidencias/laboratorio-integrador/aws/aiops/05-mttd-static-alarm-20260903T064719Z.log`).
- [x] Calcular MTTD de la alarma estática de control: 53,213 s, menor que 120 s (`evidencias/laboratorio-integrador/aws/aiops/05-mttd-static-alarm-20260903T064719Z.log`). El MTTD de anomalía dinámica sigue pendiente.
- [x] Aplicar rollback del experimento 2; Terraform reportó `2 added, 2 changed, 2 destroyed` y el equipo confirmó posteriormente Service B y `data-service` en `COMPLETED` y estables. `07-chaos-rollback-20260903T062602Z.log` conserva una captura intermedia `IN_PROGRESS`, por lo que no sustituye una tabla final.
- [x] Determinar degradación de disponibilidad y `error_rate`: 90 % y 10 %, respectivamente, frente a objetivos ≥99 % y ≤1 %; ambos incumplidos en la ventana.
- [x] Calcular consumo de error budget: el 10 % de errores consumió diez veces el presupuesto de 1 % de la ventana.
- [ ] Evaluar si cada alerta fue accionable y estuvo enriquecida con trace ID.
- [ ] Guardar capturas, resúmenes de métricas, trazas y logs necesarios.

**Criterio de salida:** dos experimentos ejecutados, MTTD inferior a dos minutos y análisis de SLO/error budget/accionabilidad.

**Análisis parcial del experimento 2:** 30 solicitudes con 27 HTTP 201 y 3 HTTP 503 implican disponibilidad de 90 % y `error_rate` de 10 %. Frente al SLO aprobado de disponibilidad ≥99 % y `error_rate` ≤1 %, la ventana supera diez veces el presupuesto de error del 1 %. La alarma estática detectó el datapoint en 53,213 s. La latencia p99 durante el caos no fue medida; por ello todavía no se puede cerrar la evaluación completa del SLO ni del error budget.

## 10. Fase 7 - Madurez y roadmap

- [ ] Confirmar los ocho dominios exactos del Observability Foundation Blueprint que utilizará la asignatura.
- [x] Preparar una autoevaluación operativa de ocho dominios con evidencia y nivel 1–5 en el informe final; queda pendiente validarla contra el blueprint exacto de la asignatura.
- [x] Identificar brechas entre el nivel actual y el siguiente nivel en el informe final.
- [x] Preparar un roadmap de mejora a tres meses con prioridad, responsable sugerido y criterio de éxito en el informe final.
- [x] Revisar que cada iniciativa del roadmap sea accionable y medible en el informe final.

**Criterio de salida:** autoevaluación completa y roadmap verificable de tres meses.

## 11. Fase 8 - Evidencias, demostración y entrega

- [x] Preparar el informe final con índice de evidencias, arquitectura, resultados, brechas, madurez, roadmap y guion de demostración (`evidencias/laboratorio-integrador/INFORME_FINAL_LABORATORIO_INTEGRADOR_AWS.md`).
- [ ] Evitar subir credenciales, secretos, estados Terraform sensibles o archivos raw masivos.
- [x] Documentar arquitectura final y flujo de correlación entre métricas, logs y trazas en el informe final.
- [x] Preparar guion de demostración técnica en vivo en el informe final; la demostración final continúa pendiente.
- [ ] Mostrar en la demostración: tres servicios en AWS, mesh, anomalía, alerta, dashboard de seguridad y chaos.
- [ ] Auditar el resultado contra la rúbrica y declarar explícitamente los criterios multicloud no cubiertos.
- [ ] Confirmar que el repositorio continúe público.
- [ ] Crear el tag `v1.0` únicamente después de aprobar la auditoría final.
- [ ] Publicar el tag y verificarlo remotamente.
- [ ] Documentar el formato final de entrega cuando la plataforma o la docente lo especifique; no inventarlo.

**Criterio de salida:** evidencia trazable, demostración ensayada, rúbrica completa y tag `v1.0` publicado.

## Riesgos que deben controlarse

| Riesgo | Control propuesto |
|---|---|
| Costos AWS inesperados | Presupuesto, alertas, tags y destrucción programada del sandbox. |
| Secretos en Git | Secrets Manager/Secret Manager y revisión automática antes de cada push. |
| Chaos sobre recursos compartidos | Cuenta/proyecto sandbox, blast radius mínimo y abort conditions. |
| Evidencia insuficiente | Definir evidencia esperada y timestamps antes de ejecutar cada prueba. |
| MTTD no comparable | Fuente horaria única y fórmula común para inicio/detección. |
| Alertas “dinámicas” no demostrables | Conservar baseline, `σ`, umbral calculado y grupo de control estático. |
| Telemetría sin correlación | Propagación W3C y verificación de trace ID en servicios, alertas y logs. |
| Datos sensibles en spans | Aplicar convenciones semánticas sin incluir consultas, credenciales ni PII. |
| Tag prematuro | Crear `v1.0` solo después de pruebas y auditoría final. |

## Registro de decisiones

| Fecha | Decisión | Estado |
|---|---|---|
| 2026-09-01 | Reutilizar `observabilidad_taller_22` y extender el trabajo del laboratorio 2.2. | Aprobada por el equipo. |
| 2026-09-01 | Mantener un plan incremental con casillas marcadas a medida que avance el trabajo. | Aprobada por el equipo. |
| 2026-09-01 | Implementar únicamente en AWS y aceptar el impacto sobre los criterios multicloud. | Aprobada por el equipo. |
| 2026-09-02 | Exigir `Idempotency-Key` para crear pedidos y persistirlo con unicidad; una clave reutilizada con otro payload produce conflicto. | Aprobada por el equipo. |
| 2026-09-02 | Usar temporalmente una topología AWS sin NAT para el sandbox: ECS/Fargate en subredes públicas con ingreso bloqueado, ALB solo para A y RDS privado. | Aprobada por el equipo como optimización académica de costos; no es el patrón recomendado para producción. |
| 2026-09-02 | Continuar el despliegue en una cuenta AWS nueva sin las restricciones de permisos del sandbox académico anterior. | Aprobada por el equipo; se mantiene el alcance exclusivamente AWS. |
| 2026-09-02 | Aplicar la topología Terraform completa en la cuenta AWS nueva. | Ejecutada: 94 recursos creados sin cambios ni destrucciones. |

## Próximo paso

Revisar el informe final y las evidencias, ejecutar la demostración técnica, auditar el contenido contra la rúbrica, y solo después crear/publicar el tag `v1.0`. Las brechas técnicas restantes (AIOps dinámico, p99 durante caos, correlación `trace_id`, ruido/accionabilidad y dashboard de seguridad) deben permanecer explícitas; no se deben presentar como completadas.
