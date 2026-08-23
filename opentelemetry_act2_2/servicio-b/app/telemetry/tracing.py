import os

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace.export import BatchSpanProcessor

from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import (
    OTLPSpanExporter
)


def configurar_tracing():

    otlp_endpoint = os.getenv(
        "OTEL_EXPORTER_OTLP_ENDPOINT",
        "localhost:4317"
    )

    resource = Resource.create({
        "service.name": "servicio-b"
    })

    provider = TracerProvider(
        resource=resource
    )

    exporter = OTLPSpanExporter(
        endpoint=otlp_endpoint,
        insecure=True
    )

    procesador = BatchSpanProcessor(
        exporter
    )

    provider.add_span_processor(
        procesador
    )

    trace.set_tracer_provider(
        provider
    )

    HTTPXClientInstrumentor().instrument()