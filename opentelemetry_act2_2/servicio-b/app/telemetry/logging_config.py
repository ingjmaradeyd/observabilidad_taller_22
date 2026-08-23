import logging
import os

from opentelemetry import _logs

from opentelemetry.sdk.resources import Resource

from opentelemetry.sdk._logs import (
    LoggerProvider,
    LoggingHandler
)

from opentelemetry.sdk._logs.export import (
    BatchLogRecordProcessor
)

from opentelemetry.exporter.otlp.proto.grpc._log_exporter import (
    OTLPLogExporter
)


def configurar_logging():

    endpoint = os.getenv(
        "OTEL_EXPORTER_OTLP_ENDPOINT",
        "localhost:4317"
    )

    resource = Resource.create({

        "service.name": "servicio-b"

    })

    logger_provider = LoggerProvider(

        resource=resource

    )

    exporter = OTLPLogExporter(

        endpoint=endpoint,

        insecure=True

    )

    processor = BatchLogRecordProcessor(

        exporter

    )

    logger_provider.add_log_record_processor(

        processor

    )

    _logs.set_logger_provider(

        logger_provider

    )

    handler = LoggingHandler(

        level=logging.INFO,

        logger_provider=logger_provider

    )

    logger = logging.getLogger()

    logger.handlers.clear()

    logger.addHandler(handler)

    logger.setLevel(logging.INFO)