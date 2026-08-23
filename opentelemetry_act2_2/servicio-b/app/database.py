from urllib.parse import quote_plus
import os

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
import logging

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "opentelemetry_bd")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "123456789")

DATABASE_URL = (
    f"postgresql+psycopg://"
    f"{quote_plus(DB_USER)}:"
    f"{quote_plus(DB_PASSWORD)}@"
    f"{DB_HOST}:{DB_PORT}/{DB_NAME}"
)


engine = create_engine(DATABASE_URL)

if os.getenv("OTEL_ENABLED", "true").lower() == "true":
    SQLAlchemyInstrumentor().instrument(engine=engine)
logging.info("Conectado a la base de datos")
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine)