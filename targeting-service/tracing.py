"""
Configuração do OpenTelemetry (traces) para o targeting-service.

Exporta os traces via OTLP/HTTP para o OTel Collector que roda dentro do
próprio cluster (observability/otel-collector) — o Collector é o roteador
central de telemetria da Fase 4: deriva métricas RED via o connector
"spanmetrics" e repassa tudo para o New Relic (APM comercial desta fase).

Instrumenta automaticamente:
  - Flask (cada rota recebida vira um span raiz, ou span filho se a
    requisição já chegar com um header "traceparent" propagado — é assim
    que o trace do evaluation-service continua até aqui);
  - requests (chamadas de saída para o auth-service, para validar a
    chave de API, aparecem como span filho);
  - psycopg2 (cada query no Postgres aparece como span filho).
"""
import os
import logging

from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.psycopg2 import Psycopg2Instrumentor

log = logging.getLogger(__name__)

DEFAULT_OTLP_ENDPOINT = (
    "http://otel-collector.observability.svc.cluster.local:4318/v1/traces"
)


def setup_tracing(flask_app, service_name="targeting-service"):
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
    except Exception as exc:  # nunca derruba a aplicação por falha de telemetria
        log.warning("Não foi possível inicializar o exporter OTLP: %s", exc)

    trace.set_tracer_provider(provider)

    FlaskInstrumentor().instrument_app(flask_app)
    RequestsInstrumentor().instrument()
    try:
        Psycopg2Instrumentor().instrument()
    except Exception as exc:
        log.warning("Não foi possível instrumentar o psycopg2: %s", exc)

    log.info("OpenTelemetry (traces) inicializado: service=%s endpoint=%s",
              service_name, endpoint)
