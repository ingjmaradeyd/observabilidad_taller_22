import logging

from opentelemetry import _logs, metrics, trace
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

from app.config import settings


SERVICE_NAME = "data-service"


def configure_telemetry() -> None:
    if not settings.otel_enabled:
        return

    resource = Resource.create({"service.name": SERVICE_NAME})
    _configure_traces(resource)
    _configure_metrics(resource)
    _configure_logs(resource)


def _configure_traces(resource: Resource) -> None:
    provider = TracerProvider(resource=resource)
    provider.add_span_processor(
        BatchSpanProcessor(
            OTLPSpanExporter(endpoint=settings.otlp_endpoint, insecure=True)
        )
    )
    trace.set_tracer_provider(provider)


def _configure_metrics(resource: Resource) -> None:
    reader = PeriodicExportingMetricReader(
        OTLPMetricExporter(endpoint=settings.otlp_endpoint, insecure=True),
        export_interval_millis=5000,
    )
    metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=[reader]))


def _configure_logs(resource: Resource) -> None:
    provider = LoggerProvider(resource=resource)
    provider.add_log_record_processor(
        BatchLogRecordProcessor(
            OTLPLogExporter(endpoint=settings.otlp_endpoint, insecure=True)
        )
    )
    _logs.set_logger_provider(provider)

    handler = LoggingHandler(level=logging.INFO, logger_provider=provider)
    root_logger = logging.getLogger()
    root_logger.handlers.clear()
    root_logger.addHandler(handler)
    root_logger.setLevel(logging.INFO)


meter = metrics.get_meter(SERVICE_NAME)
orders_created = meter.create_counter(
    "data_service_orders_created",
    description="Orders created by data-service",
)
orders_failed = meter.create_counter(
    "data_service_orders_failed",
    description="Order creation failures by stable reason",
)
order_duration = meter.create_histogram(
    "data_service_order_creation_duration",
    description="Order creation duration",
    unit="ms",
)


class OtelOrderMetrics:
    def record_created(self) -> None:
        orders_created.add(1, {"outcome": "created"})

    def record_failure(self, reason: str) -> None:
        orders_failed.add(1, {"reason": reason})

    def record_duration(self, duration_ms: float) -> None:
        order_duration.record(duration_ms)
