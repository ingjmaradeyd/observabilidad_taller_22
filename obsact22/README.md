# Laboratorio 2.2 Observabilidad - Terraform

Este paquete implementa la arquitectura definida:

- 1 VPC
- 2 Zonas de Disponibilidad (Availability Zones)
- 2 subredes públicas
- 2 subredes privadas para las aplicaciones
- 2 subredes privadas para la base de datos
- Internet Gateway
- 1 NAT Gateway (diseño del laboratorio optimizado en costos)
- ALB expuesto a Internet
- Listener HTTP :80
- 2 Target Groups con tipo de target `ip`
  - Target Group para service-a
  - Target Group para service-b
- Enrutamiento basado en rutas:
  - `/service-a` y `/service-a/*` -> Service A
  - `/service-b` y `/service-b/*` -> Service B
- Un repositorio ECR para cada microservicio
- 1 clúster ECS
- 2 servicios ECS ejecutándose sobre Fargate
- 2 definiciones de tareas (ECS Task Definitions)
- Service A -> Service B mediante HTTP privado utilizando AWS Cloud Map
- Ambos servicios -> PostgreSQL RDS
- Contraseña maestra de RDS administrada mediante AWS Secrets Manager
- CloudWatch Logs
- Roles IAM para ejecución de tareas y para las propias tareas
- Security Groups

## ¿Por qué desired_count comienza en 0?

Terraform puede crear los repositorios ECR y las definiciones de tareas incluso antes de que existan las imágenes Docker.

Si ECS inicia las tareas antes de que las imágenes hayan sido cargadas en ECR, las tareas fallarán al intentar descargar las imágenes.

Primera ejecución:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Luego, se deben cargar las imágenes Docker en los repositorios ECR que Terraform mostrará en sus outputs.

Después, cambiar:

```hcl
service_a_desired_count = 2
service_b_desired_count = 2
```

y ejecutar nuevamente:

```bash
terraform plan
terraform apply
```

## Requisitos importantes de las aplicaciones

Los contenedores deben exponer:

- Service A: puerto 8000
- Service B: puerto 8001
- `/health` debe retornar un código HTTP entre 200 y 399

Ambas aplicaciones reciben las siguientes variables de entorno:

- DB_HOST
- DB_PORT
- DB_NAME
- DB_USER
- DB_PASSWORD

Service A recibe adicionalmente:

- SERVICE_B_URL

`SERVICE_B_URL` utiliza el DNS privado de AWS Cloud Map, por lo que Service A no necesita comunicarse con Service B a través del ALB público.

## Validaciones realizadas antes de empaquetar

Este paquete fue revisado para verificar:

- Direcciones de recursos Terraform duplicadas.
- Bloques HCL de una sola línea con múltiples argumentos, como los que generaron los errores anteriores.
- Balance correcto de llaves.
- Recursos de CloudWatch Log Groups duplicados.

El entorno de ejecución utilizado para generar este paquete no tiene instalado el binario de Terraform, por lo que no fue posible ejecutar directamente `terraform validate`.
