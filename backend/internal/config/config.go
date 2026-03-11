package config

import (
	"log"
	"os"
	"path/filepath"
	"strings"
	"unicode/utf8"

	"github.com/joho/godotenv"
)

type Config struct {
	HTTPAddr   string
	DB         DBConfig
	KServe     KServeConfig
	S3         S3Config
	JWT        JWTConfig
	Moderation ModerationConfig // <-- NEW
}

type DBConfig struct {
	DSN string
}

type KServeConfig struct {
	BaseURL string
}

type S3Config struct {
	Bucket          string
	Region          string
	Endpoint        string
	BaseURL         string
	AccessKeyID     string
	SecretAccessKey string
}

type ModerationConfig struct {
	BaseURL string
}

// S3Configured возвращает true, если заданы бакет и ключи доступа (S3 обязателен для загрузки).
func (s S3Config) S3Configured() bool {
	return s.Bucket != "" && s.AccessKeyID != "" && s.SecretAccessKey != ""
}

type JWTConfig struct {
	Secret     string
	Expiration int
}

func Load() *Config {
	// Загружаем .env из нескольких мест (последний загруженный перезаписывает переменные)
	paths := []string{".env", "backend/.env"}
	if execPath, err := os.Executable(); err == nil {
		paths = append(paths, filepath.Join(filepath.Dir(execPath), ".env"))
	}
	var loaded string
	for _, p := range paths {
		if err := loadEnvFile(p); err == nil {
			loaded = p
		}
	}
	if loaded != "" {
		log.Printf("config: loaded .env from %s (cwd: %s)", loaded, mustGetwd())
	} else {
		cwd := mustGetwd()
		log.Printf("config: no .env file (cwd: %s); using process environment (in Docker: env_file / environment)", cwd)
	}

	return &Config{
		HTTPAddr: getEnv("HTTP_ADDR", ":8080"),
		DB: DBConfig{
			DSN: getEnv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/petio?sslmode=disable"),
		},
		KServe: KServeConfig{
			BaseURL: getEnv("KSERVE_URL", ""),
		},
		S3: S3Config{
			Bucket:          getEnv("S3_BUCKET", ""),
			Region:          getEnv("S3_REGION", "ru-central1"),
			Endpoint:        getEnv("S3_ENDPOINT", "https://storage.yandexcloud.net"),
			BaseURL:         getEnv("S3_BASE_URL", ""),
			AccessKeyID:     getEnv("AWS_ACCESS_KEY_ID", getEnv("S3_ACCESS_KEY_ID", "")),
			SecretAccessKey: getEnv("AWS_SECRET_ACCESS_KEY", getEnv("S3_SECRET_ACCESS_KEY", "")),
		},
		JWT: JWTConfig{
			Secret:     getEnv("JWT_SECRET", "change-me-in-production"),
			Expiration: 24 * 7,
		},
		Moderation: ModerationConfig{
			BaseURL: getEnv("MODERATION_URL", ""),
		},
	}
}

func getEnv(key, defaultVal string) string {
	v := os.Getenv(key)
	// На Windows .env в UTF-8 с BOM: первая переменная может иметь ключ с BOM
	if v == "" && utf8.ValidString(key) {
		v = os.Getenv("\ufeff" + key)
	}
	v = strings.TrimSpace(v)
	if v != "" {
		return v
	}
	return defaultVal
}

// loadEnvFile загружает .env, убирая BOM из начала файла (частая проблема в Windows).
func loadEnvFile(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	text := string(data)
	if strings.HasPrefix(text, "\ufeff") {
		text = strings.TrimPrefix(text, "\ufeff")
	}
	envMap, err := godotenv.Unmarshal(text)
	if err != nil {
		return err
	}
	for k, v := range envMap {
		k = strings.TrimSpace(strings.TrimPrefix(k, "\ufeff"))
		os.Setenv(k, strings.TrimSpace(v))
	}
	return nil
}

func mustGetwd() string {
	d, _ := os.Getwd()
	return d
}
