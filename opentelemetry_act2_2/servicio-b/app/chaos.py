import logging
import time
from collections.abc import Callable

from opentelemetry import trace


logger = logging.getLogger(__name__)


def inject_configured_latency(
    *,
    enabled: bool,
    latency_ms: int,
    sleep: Callable[[float], None] = time.sleep,
) -> bool:
    if not enabled or latency_ms == 0:
        return False

    current_span = trace.get_current_span()
    if current_span.is_recording():
        current_span.set_attribute("chaos.enabled", True)
        current_span.set_attribute("chaos.type", "latency")
        current_span.set_attribute("chaos.latency_ms", latency_ms)

    logger.info(
        "Injecting configured latency before customer lookup",
        extra={
            "event_name": "chaos.latency.injected",
            "chaos_latency_ms": latency_ms,
        },
    )
    sleep(latency_ms / 1000)
    return True
