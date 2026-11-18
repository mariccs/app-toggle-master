"""
Configuração do OpenTelemetry (traces) para o analytics-service.

Exporta os traces via OTLP/HTTP para o OTel Collector que roda dentro do
próprio cluster (observability/otel-collector), mesmo papel descrito em
flag-service/tracing.py: o Collector é o roteador central de telemetria
desta fase.

Instrumenta automaticamente:
  - Flask (endpoint /health);
  - botocore (toda chamada ao SQS e ao DynamoDB via boto3 aparece como
    span filho — é a parte mais importante aqui, já que o trabalho real
    deste serviço é consumir a fila SQS e escrever no DynamoDB, não
    servir HTTP).
"""
import os
import logging

from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.botocore import BotocoreInstrumentor

log = logging.getLogger(__name__)

DEFAULT_OTLP_ENDPOINT = (
    "http://otel-collector.observability.svc.cluster.local:4318/v1/traces"
)


def setup_tracing(flask_app, service_name="analytics-service"):
    endpoint = os.getenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", DEFAULT_OTLP_ENDPOINT)

    resource = Resource.create({
        "service.name": os.getenv("OTEL_SERVICE_NAME", service_name),
        "service.version": os.getenv("SERVICE_VERSION", "v1.0.0"),
        "deployment.environment": os.getenv("DEPLOYMENT_ENV", "sandbox"),
    })

    provider = TracerProvider(resource=resource)
    try:
        exporter = OTLPSpanExporter(endpoint=endpoint)
        provider.add_span_processor(BatchSpanProcessor(exporter))
    except Exception as exc:
        log.warning("Não foi possível inicializar o exporter OTLP: %s", exc)

    trace.set_tracer_provider(provider)

    FlaskInstrumentor().instrument_app(flask_app)
    try:
        BotocoreInstrumentor().instrument()
    except Exception as exc:
        log.warning("Não foi possível instrumentar o botocore (SQS/DynamoDB): %s", exc)

    log.info("OpenTelemetry (traces) inicializado: service=%s endpoint=%s",
              service_name, endpoint)
