import os

from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter

otel_enabled = os.getenv("OTEL_ENABLED", "true").lower() == "true"
endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "localhost:4317")

if otel_enabled:
    resource = Resource.create({"service.name": "servicio-b"})
    exporter = OTLPMetricExporter(endpoint=endpoint, insecure=True)
    reader = PeriodicExportingMetricReader(exporter, export_interval_millis=5000)
    provider = MeterProvider(resource=resource, metric_readers=[reader])
    metrics.set_meter_provider(provider)

meter = metrics.get_meter("servicio-b")

clientes_consultados = meter.create_counter(
    name="clientes_consultados",
    description="Cantidad total de clientes consultados"
)

clientes_no_encontrados = meter.create_counter(
    name="clientes_no_encontrados",
    description="Cantidad total de clientes no encontrados"
)

duracion_consulta_cliente = meter.create_histogram(
    name="consulta_cliente_duracion",
    description="Tiempo de consulta de cliente",
    unit="ms"
)
