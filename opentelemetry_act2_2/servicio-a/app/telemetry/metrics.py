import os

from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter

otel_enabled = os.getenv("OTEL_ENABLED", "true").lower() == "true"
endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "localhost:4317")

if otel_enabled:
    resource = Resource.create({"service.name": "servicio-a"})
    exporter = OTLPMetricExporter(endpoint=endpoint, insecure=True)
    reader = PeriodicExportingMetricReader(exporter, export_interval_millis=5000)
    provider = MeterProvider(resource=resource, metric_readers=[reader])
    metrics.set_meter_provider(provider)

meter = metrics.get_meter("servicio-a")

pedidos_creados = meter.create_counter(
    name="pedidos_creados",
    description="Cantidad total de pedidos creados"
)

pedidos_fallidos = meter.create_counter(
    name="pedidos_fallidos",
    description="Cantidad total de pedidos fallidos"
)

duracion_creacion_pedido = meter.create_histogram(
    name="pedido_creacion_duracion",
    description="Tiempo de creación de pedidos",
    unit="ms"
)
