import logging

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.config import settings


logger = logging.getLogger(__name__)

engine = create_engine(
    settings.database_url,
    pool_size=settings.db_pool_size,
    max_overflow=0,
    pool_timeout=settings.db_pool_timeout_seconds,
    connect_args={
        "connect_timeout": settings.db_connect_timeout_seconds,
        "options": (
            f"-c statement_timeout={settings.db_statement_timeout_ms} "
            f"-c lock_timeout={settings.db_lock_timeout_ms}"
        ),
    },
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

logger.info("Database engine configured", extra={"event_name": "database.configured"})
