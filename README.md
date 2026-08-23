# Cierre del taller OpenTelemetry

## Flujo final
service-a -> service-b -> PostgreSQL; ambos servicios envían OTLP gRPC al ADOT Collector por Cloud Map. El Collector procesa traces, metrics y logs y los exporta a endpoints OTLP de AWS CloudWatch/X-Ray usando SigV4.

## Correcciones incorporadas
- Endpoint de negocio de service-a: POST /pedidos/crear.
- Métricas de service-b corregidas: clientes_consultados, clientes_no_encontrados, consulta_cliente_duracion.
- service.name agregado al MeterProvider de ambos servicios.
- OTEL_EXPORTER_OTLP_ENDPOINT agregado a service-a y service-b en ECS.
- Referencias ADOT corregidas para usar recursos del mismo root Terraform.
- Dockerfile ADOT corregido para cargar el archivo de configuración correcto.

## Secuencia de despliegue
1. terraform fmt -recursive && terraform validate && terraform plan
2. terraform apply
3. Construir y publicar imagen ADOT en el ECR indicado por `terraform output adot_ecr_repository_url`.
4. Cambiar `adot_desired_count = 1` y ejecutar nuevamente `terraform apply`.
5. Construir/publicar service-a y service-b si hay cambios de código.
6. Forzar nuevo deployment de los servicios ECS si las etiquetas son `latest`.
7. Probar GET /health en A y B.
8. Probar POST /pedidos/crear en service-a.
9. Verificar trazas en CloudWatch/X-Ray, métricas OTel en CloudWatch y logs en el log group configurado. Para el endpoint OTLP de trazas de X-Ray/CloudWatch, habilitar Transaction Search en la cuenta/región si aún no está habilitado.

## Prueba funcional sugerida
POST /pedidos/crear
```json
{
  "id_cliente": 1,
  "producto": "Laptop",
  "cantidad": 1,
  "valor": 3500000
}
```


## Benchmark con/sin OpenTelemetry
Terraform deja `OTEL_ENABLED=true` en ambos servicios. Para el baseline, cambiar temporalmente a `false` en ambos task definitions, aplicar y forzar deployment. Ejecutar:

```bash
BASE_URL=http://<ALB>/service-a k6 run --summary-export=sin-otel.json benchmark/pedidos-k6.js
```

Luego volver `OTEL_ENABLED=true`, aplicar/forzar deployment y repetir:

```bash
BASE_URL=http://<ALB>/service-a k6 run --summary-export=con-otel.json benchmark/pedidos-k6.js
```

Registrar p95, p99, requests/s, error rate y complementar con CPU/memoria de ECS/CloudWatch en `benchmark/resultados.csv`.
