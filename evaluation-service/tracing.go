package main

import (
	"context"
	"log"
	"os"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)

// initTracer configura o SDK do OpenTelemetry para exportar traces via
// OTLP/HTTP para o OTel Collector que roda dentro do próprio cluster
// (observability/otel-collector). O Collector é quem decide o que fazer
// com esses traces: deriva métricas RED via o connector "spanmetrics" e
// repassa para o New Relic (APM comercial desta fase).
func initTracer() func(context.Context) error {
	ctx := context.Background()

	endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if endpoint == "" {
		// Endpoint HTTP do Collector, dentro do namespace "observability".
		endpoint = "otel-collector.observability.svc.cluster.local:4318"
	}

	serviceName := os.Getenv("OTEL_SERVICE_NAME")
	if serviceName == "" {
		serviceName = "evaluation-service"
	}

	exporter, err := otlptracehttp.New(
		ctx,
		otlptracehttp.WithEndpoint(endpoint),
		otlptracehttp.WithInsecure(), // tráfego interno do cluster, sem TLS
	)
	if err != nil {
		log.Printf("Aviso: não foi possível inicializar o exporter OTLP de traces: %v", err)
		return func(context.Context) error { return nil }
	}

	res, err := resource.New(
		ctx,
		resource.WithAttributes(
			semconv.ServiceName(serviceName),
			semconv.ServiceVersion(envOrDefault("SERVICE_VERSION", "v1.0.0")),
			semconv.DeploymentEnvironment(envOrDefault("DEPLOYMENT_ENV", "sandbox")),
		),
	)
	if err != nil {
		log.Printf("Aviso: não foi possível construir o resource do OTel: %v", err)
		res = resource.Default()
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter, sdktrace.WithBatchTimeout(5*time.Second)),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	log.Printf("OpenTelemetry (traces) inicializado: service=%s endpoint=%s", serviceName, endpoint)

	return tp.Shutdown
}

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
