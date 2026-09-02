# Diseño de la base AWS sin NAT para el laboratorio integrador

## Decisión

La base del laboratorio se desplegará exclusivamente en `us-east-1` con una topología temporal sin NAT Gateway. El Application Load Balancer (ALB) será el único punto de entrada público y solo enviará tráfico a Service A. Las tareas de ECS/Fargate se ubicarán en las dos subredes públicas existentes con `assign_public_ip = true` para alcanzar dependencias de salida; sus grupos de seguridad impedirán todo ingreso directo desde Internet. Service A accederá a Service B y `data-service` mediante ECS Service Connect, y únicamente Service B y `data-service` podrán conectarse a RDS PostgreSQL.

Esta decisión optimiza el costo de un sandbox académico con límite manual de USD 20. **No representa la topología recomendada para producción**: en un ambiente productivo se preferirían tareas en subredes privadas, NAT administrado o VPC endpoints seleccionados según costo, disponibilidad y requisitos de seguridad.

> Este documento define el diseño y sus controles. No creó, modificó ni eliminó recursos en AWS.

## Objetivo y alcance

### Objetivo

Preparar una base AWS mínima, reproducible y destruible para ejecutar tres microservicios observables:

- Service A como única API pública.
- Service B como servicio privado propietario de las consultas de clientes.
- `data-service` como servicio privado propietario de la persistencia de pedidos.
- RDS PostgreSQL privado y compartido, con propiedad lógica de tablas separada.
- ECS Service Connect para comunicación y visibilidad L7 entre servicios.

### Fuera de alcance de esta unidad de diseño

- Desplegar recursos o ejecutar `terraform apply`.
- Implementar GCP; el alcance AWS-only es una restricción aceptada y limita el máximo estricto de la rúbrica.
- Habilitar en esta unidad OpenTelemetry, AIOps, VPC Flow Logs, dashboards o experimentos de caos.
- Ejecutar migraciones desde Terraform mediante `local-exec`.
- Introducir NAT Gateway, VPC endpoints, alta disponibilidad Multi-AZ o escalamiento automático.
- Rediseñar las APIs o agregar funcionalidades distintas de las solicitadas por la actividad.

## Estado actual y brechas verificadas

| Área | Estado actual en Terraform | Brecha respecto del diseño aprobado |
|---|---|---|
| Red | VPC `10.20.0.0/16`, dos subredes públicas, dos privadas de aplicación, dos privadas de base de datos, IGW, EIP y NAT Gateway. | Eliminar del estado deseado el NAT, su EIP, las subredes privadas de aplicación y su tabla/ruta por defecto; conservar públicas y privadas de base de datos. |
| Entrada pública | El ALB expone Service A y Service B. | Mantener únicamente la ruta y target group de Service A; retirar la regla, target group y URL pública de Service B. |
| ECS | Existen definiciones/servicios para A y B; `data-service` solo tiene ECR. | Agregar tarea y servicio de `data-service`; ubicar A/B/data en subredes públicas sin ingreso público directo. |
| Descubrimiento | Cloud Map registra únicamente Service B. | Configurar un namespace de ECS Service Connect, A como cliente y B/data como servicios privados descubiertos. |
| Base de datos | RDS usa subredes privadas y contraseña maestra administrada. A y B tienen acceso y permisos de secreto. | Retirar a A el acceso de red, las variables de base de datos y el permiso al secreto; autorizar solo B y data. |
| Observabilidad | A y B parten con `OTEL_ENABLED = false`. | Habilitar e integrar OTel en una unidad posterior, después de estabilizar la base ECS. |
| Datos | El sandbox estaba vacío; una RDS nueva no contiene esquema ni datos. | Ejecutar posteriormente un bootstrap/migración idempotente y verificable. |
| Evidencia | No existe evidencia de despliegue AWS vigente. | Capturar plan revisado, recursos desplegados, pruebas de conectividad y evidencias sanitizadas. |

## Topología seleccionada

```text
Internet
   |
   v
ALB público
   |
   v
Service A (ECS/Fargate, subred pública, sin ingreso directo)
   |                         |
   | ECS Service Connect     | ECS Service Connect
   v                         v
Service B                 data-service
   |                         |
   +-----------+-------------+
               |
               v
       RDS PostgreSQL privado
       (subredes DB, sin IP pública)
```

### Tratamiento exacto de subredes y NAT

Debido a que la auditoría confirmó que el sandbox no tiene recursos desplegados, el estado deseado será el mínimo:

1. **Conservar** la VPC, el Internet Gateway, las dos subredes públicas y las dos subredes privadas de base de datos.
2. **Omitir del diseño objetivo** las dos subredes privadas de aplicación, su tabla de rutas y su asociación. No alojarán recursos en este laboratorio.
3. **Eliminar de la configuración deseada** el NAT Gateway, su Elastic IP y la ruta `0.0.0.0/0` que dependía del NAT.
4. Ubicar A, B y `data-service` en ambas subredes públicas y usar `assign_public_ip = true`.
5. No asignar IP pública a RDS y mantener `publicly_accessible = false` dentro de las dos subredes privadas de base de datos.

Si un `terraform plan` posterior detecta recursos remotos inesperados y propone destruirlos, el proceso se detendrá para revisar el estado antes de aplicar. La ausencia de NAT reduce costo, pero hace que la salida de las tareas dependa de su IP pública y del Internet Gateway.

## Matriz de tráfico y grupos de seguridad

Una IP pública en una tarea no implica que el servicio sea accesible desde Internet: el ingreso se controla exclusivamente mediante reglas de grupos de seguridad.

| Origen | Destino | Puerto/protocolo | Regla requerida | Propósito |
|---|---|---|---|---|
| Internet | ALB | TCP/80 | Ingreso público al SG del ALB | Punto de entrada del laboratorio. |
| SG del ALB | SG de Service A | TCP/8000 | Ingreso a A solo desde el SG del ALB | Invocar la API pública. |
| SG de Service A | SG de Service B | TCP/8001 | Egreso desde A e ingreso a B, referenciando ambos SG | Consulta privada de clientes mediante Service Connect. |
| SG de Service A | SG de `data-service` | TCP/8002 | Egreso desde A e ingreso a data, referenciando ambos SG | Creación privada de pedidos mediante Service Connect. |
| SG de Service B | SG de RDS | TCP/5432 | Egreso desde B e ingreso a RDS, referenciando ambos SG | Acceso a la tabla lógica de clientes. |
| SG de `data-service` | SG de RDS | TCP/5432 | Egreso desde data e ingreso a RDS, referenciando ambos SG | Acceso a la tabla lógica de pedidos. |
| Tareas ECS | Servicios AWS y repositorios externos requeridos | TCP/443 | Egreso controlado mediante IGW | ECR, CloudWatch, Secrets Manager y dependencias de ejecución. |
| Tareas ECS | Resolver DNS de la VPC | UDP/TCP 53 | Egreso DNS | Resolución de Service Connect y endpoints externos. |

Controles obligatorios:

- Service B y `data-service` no tendrán listeners, target groups ni reglas de ALB.
- Sus grupos de seguridad no admitirán `0.0.0.0/0` ni `::/0` como origen de ingreso.
- Service A no tendrá acceso al SG de RDS.
- RDS solo admitirá TCP/5432 desde los SG de B y data.
- No se publicarán como outputs URLs directas de B o data.

## RDS y propiedad de secretos

RDS PostgreSQL conservará estos valores para el sandbox:

- `publicly_accessible = false`.
- Single-AZ.
- Clase `db.t4g.micro`.
- 20 GiB de almacenamiento cifrado.
- Dos subredes privadas de base de datos.
- `manage_master_user_password = true`, con Secrets Manager como fuente de la contraseña.

La separación de responsabilidades será explícita:

- Service B será propietario lógico de `clientes`.
- `data-service` será propietario lógico de `pedidos`.
- Service A no recibirá variables de conexión, ARN del secreto ni permisos para leerlo.
- Solo las tareas de B y data recibirán la referencia del secreto y conectividad al puerto 5432.
- La política de lectura del secreto se asociará únicamente a los roles que realmente lo necesitan; se evitará una concesión global compartida con A.

Para retirar la política amplia actual, Service A tendrá un rol de ejecución base sin `secretsmanager:GetSecretValue`. Service B y `data-service` podrán compartir un rol de ejecución para cargas con base de datos, limitado al ARN del secreto administrado por RDS y a los permisos mínimos de descarga de imagen y escritura de logs. Los task roles no recibirán permisos sobre Secrets Manager si la credencial se inyecta desde la task definition.

Usar el secreto maestro para B y data es una simplificación del laboratorio. En producción deberían existir usuarios de base de datos separados, permisos mínimos y rotación diseñada por servicio.

## Límites de ECS y Service Connect

| Servicio | Exposición | Service Connect | Acceso a RDS | Secreto RDS |
|---|---|---|---|---|
| Service A | ALB público | Cliente de B y data | No | No |
| Service B | Privada | Servidor registrado en el namespace | Sí | Sí |
| `data-service` | Privada | Servidor registrado en el namespace | Sí | Sí |

La implementación posterior deberá:

- Definir nombres de puerto estables para los mappings ECS de B y data.
- Crear alias de cliente internos para que A no dependa de IPs o URLs públicas.
- Mantener health checks separados de las inyecciones de caos.
- Agregar para `data-service` su task definition, servicio ECS, SG, log group, tag de imagen inmutable, desired count y health check.
- Publicar solo A en el ALB.

El alcance de esta base termina cuando los tres servicios están saludables y A alcanza a B y data por Service Connect. La habilitación de ADOT/OTel en A, B y data, junto con la correlación de logs, métricas y trazas, pertenece a la unidad de observabilidad posterior.

## Estrategia de bootstrap y migración de base de datos

Una RDS nueva parte sin tablas ni datos. Terraform administrará infraestructura, pero **no ejecutará SQL mediante `local-exec`**.

La unidad dependiente de bootstrap utilizará una tarea ECS/Fargate de ejecución única que:

1. Use una imagen versionada e inmutable con los scripts de esquema y migraciones.
2. Se ejecute en las mismas subredes y con el mismo acceso restringido a RDS que los servicios autorizados.
3. Lea el secreto administrado desde Secrets Manager sin imprimirlo.
4. Ejecute scripts idempotentes dentro de transacciones y falle ante el primer error.
5. Registre en una tabla de control las migraciones aplicadas o verifique explícitamente el estado final.
6. Termine con código `0` solo cuando esquema, índices, restricciones y datos mínimos hayan sido validados.

La tarea no será un servicio permanente. Se ejecutará antes de aumentar el desired count de B y data. Su evidencia incluirá task ARN sanitizado, exit code, logs sin secretos y consultas de verificación. Una reejecución deberá producir el mismo estado sin duplicar datos.

## Controles de costo y destrucción

El presupuesto de USD 20 se controlará manualmente porque AWS Budgets fue pospuesto. Antes de cada despliegue se revisarán los recursos y, después de la demostración, se destruirán.

Controles:

- Omitir NAT Gateway y VPC endpoints en esta fase.
- Usar RDS Single-AZ `db.t4g.micro` con 20 GiB y `desired_count = 1` por servicio Fargate únicamente durante validación y demostración.
- Usar tags de imagen inmutables y evitar despliegues duplicados.
- Definir una retención de siete días para los log groups de CloudWatch del laboratorio.
- Etiquetar recursos con `Project = observabilidad-taller-22`, `Environment = lab`, `ManagedBy = Terraform`, `Owner = student-team` y `Purpose = academic-observability`.
- Mantener deshabilitada la protección contra eliminación para los recursos efímeros del sandbox.
- Revisar el plan de destrucción antes de ejecutar `terraform destroy`.
- Vaciar o permitir eliminación controlada de ECR y retirar recursos creados fuera de Terraform antes del cierre.

Los principales generadores de costo serán ALB, RDS, Fargate, CloudWatch y Secrets Manager. La topología deberá permanecer activa solo durante la implementación, recolección de evidencias y demostración.

## Unidades de trabajo

Cada unidad requiere revisión antes de continuar con la siguiente:

1. **Base de red y seguridad:** retirar NAT/EIP/subredes privadas de aplicación, ubicar ECS en subredes públicas y aplicar la matriz de SG.
2. **ECS y Service Connect:** retirar la exposición de B, agregar `data-service` y conectar A con B/data mediante el namespace privado.
3. **Imágenes versionadas:** construir y publicar A, B, data y ADOT en ECR con tags inmutables y escaneo básico.
4. **Plan y despliegue de infraestructura:** validar permisos, revisar `terraform plan` y solicitar aprobación antes de `apply`.
5. **Bootstrap RDS:** ejecutar la tarea one-shot idempotente y verificar esquema/datos.
6. **Smoke test AWS:** comprobar salud, flujo A -> B -> data -> RDS y ausencia de rutas públicas a B/data.
7. **Observabilidad completa:** habilitar OTel/ADOT en A, B y data; exportar y correlacionar los tres pilares.
8. **Evidencia y cierre:** capturar pruebas sanitizadas y destruir todos los recursos después de la demostración.

No se implementarán varias unidades en un único cambio sin una revisión intermedia, especialmente antes de cualquier creación o destrucción en AWS.

## Validación y evidencias requeridas

### Antes de aplicar

- [ ] `terraform fmt -check -recursive` sin cambios pendientes.
- [ ] `terraform validate` exitoso.
- [ ] Permisos efectivos del sandbox comprobados para los recursos del plan.
- [ ] `terraform plan` revisado: sin NAT/EIP, sin exposición de B/data y sin destrucciones inesperadas.
- [ ] Estimación manual de los recursos que generan costo.
- [ ] Aprobación explícita del plan antes de `terraform apply`.

### Después de aplicar

- [ ] ALB público responde únicamente por la ruta de Service A.
- [ ] No existen listeners, reglas, target groups ni outputs públicos para B/data.
- [ ] Los SG de B/data no tienen ingreso desde Internet.
- [ ] RDS reporta `PubliclyAccessible = false`, cifrado y la clase/tamaño aprobados.
- [ ] A no contiene secretos ni conectividad a RDS; B/data sí acceden de manera controlada.
- [ ] Service Connect muestra B y data registrados y saludables.
- [ ] Una solicitud crea un pedido a través de A -> B -> data -> RDS.
- [ ] La tarea de migración termina con código `0` y demuestra reejecución idempotente.
- [ ] Las capturas y salidas no incluyen AccountId completo, credenciales, tokens ni contenido de secretos.
- [ ] `terraform plan -destroy` permite retirar todos los recursos creados.

Evidencia mínima: resumen sanitizado del plan, diagrama/topología final, servicios ECS saludables, configuración de Service Connect, reglas de SG, estado privado de RDS, logs del bootstrap, prueba funcional y plan de destrucción.

## Riesgos y rollback

| Riesgo | Señal | Mitigación | Rollback |
|---|---|---|---|
| Exposición accidental de B/data | Regla `0.0.0.0/0`, listener o URL pública. | Revisión del plan y prueba externa negativa. | Reducir desired count a cero y corregir SG/ALB antes de continuar. |
| Falta de salida de Fargate | Fallos al descargar imágenes o enviar logs. | Confirmar subred pública, ruta al IGW y `assign_public_ip = true`. | Detener servicios, corregir red y desplegar una nueva revisión de tarea. |
| Service Connect mal configurado | A no resuelve o no alcanza B/data. | Validar namespace, `port_name`, alias y SG. | Restaurar la revisión anterior de task/service sin exponer servicios públicamente. |
| Permisos insuficientes del sandbox | `AccessDenied` en plan/aplicación. | Preflight de permisos antes de crear recursos. | No aplicar; ajustar alcance solo con aprobación del equipo. |
| Migración parcial | Tarea termina con error o esquema incompleto. | Transacciones, `ON_ERROR_STOP` y scripts idempotentes. | Corregir el script y reejecutar; restaurar snapshot solo si se hubiera aprobado uno. |
| Consumo superior a USD 20 | Recursos activos más tiempo del previsto. | Ventana corta, monitoreo manual y teardown inmediato. | Reducir desired count y ejecutar destrucción revisada. |
| Pérdida de evidencia durante el teardown | Recursos destruidos antes de documentar. | Checklist de capturas y consultas antes del cierre. | Conservar artefactos sanitizados en Git; recrear solo con plan aprobado. |

## Puerta de revisión

El siguiente paso es la revisión humana de este diseño. Solo después de su aprobación se modificará Terraform. Antes de cualquier `apply` se realizará una segunda puerta: revisión de `terraform plan` y verificación de permisos efectivos del sandbox.
