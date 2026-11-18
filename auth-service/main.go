package main

import (
	"context"
	"database/sql"
	"log"
	"net/http"
	"os"

	_ "github.com/jackc/pgx/v4/stdlib"
	"github.com/joho/godotenv"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

// App struct (para injeção de dependência)
type App struct {
	DB        *sql.DB
	MasterKey string
	// ChaosEnabled controla o endpoint /chaos/5xx, usado só para a
	// demonstração da Fase 4 (provocar deliberadamente a falha que
	// dispara o alerta de taxa de 5xx > 5%). Fica desligado por padrão.
	ChaosEnabled bool
}

func main() {
	// Carrega o .env para desenvolvimento local. Em produção, isso não fará nada.
	_ = godotenv.Load()

	// Inicializa o OpenTelemetry (traces) antes de tudo.
	shutdownTracer := initTracer()
	defer func() {
		if err := shutdownTracer(context.Background()); err != nil {
			log.Printf("Erro ao finalizar o tracer provider: %v", err)
		}
	}()

	// --- Configuração ---
	port := os.Getenv("PORT")
	if port == "" {
		port = "8001" // Porta padrão
	}

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL deve ser definida")
	}

	masterKey := os.Getenv("MASTER_KEY")
	if masterKey == "" {
		log.Fatal("MASTER_KEY deve ser definida")
	}

	// --- Conexão com o Banco ---
	db, err := connectDB(databaseURL)
	if err != nil {
		log.Fatalf("Não foi possível conectar ao banco de dados: %v", err)
	}
	defer func() {
		if err := db.Close(); err != nil {
			log.Printf("Erro ao fechar conexão com o banco: %v", err)
		}
	}()

	app := &App{
		DB:           db,
		MasterKey:    masterKey,
		ChaosEnabled: os.Getenv("CHAOS_ENDPOINT_ENABLED") == "true",
	}

	// --- Rotas da API ---
	mux := http.NewServeMux()
	mux.HandleFunc("/health", app.healthHandler)

	// Endpoint público para validar uma chave
	mux.HandleFunc("/validate", app.validateKeyHandler)

	// Endpoints de "admin" para criar/gerenciar chaves
	// Eles são protegidos pelo middleware de autenticação
	mux.Handle("/admin/keys", app.masterKeyAuthMiddleware(http.HandlerFunc(app.createKeyHandler)))

	// Endpoint só para a demonstração da Fase 4: provoca 500 de propósito,
	// para disparar o alerta "AuthServiceHigh5xxRate" ao vivo no vídeo.
	// Só existe se CHAOS_ENDPOINT_ENABLED=true (desligado por padrão).
	mux.HandleFunc("/chaos/5xx", app.chaosHandler)

	// Envolve o mux com o middleware do OpenTelemetry: toda requisição
	// (inclusive as que o endpoint de chaos provoca) gera um span,
	// visível no New Relic e correlacionado ao alerta no Grafana.
	instrumentedMux := otelhttp.NewHandler(mux, "auth-service")

	log.Printf("Serviço de Autenticação (Go) rodando na porta %s", port)
	if err := http.ListenAndServe(":"+port, instrumentedMux); err != nil {
		log.Fatal(err)
	}
}

// connectDB inicializa e testa a conexão com o PostgreSQL
func connectDB(databaseURL string) (*sql.DB, error) {
	db, err := sql.Open("pgx", databaseURL)
	if err != nil {
		return nil, err
	}

	if err = db.Ping(); err != nil {
		return nil, err
	}

	log.Println("Conectado ao PostgreSQL com sucesso!")
	return db, nil
}
