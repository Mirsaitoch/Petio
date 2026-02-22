package config

import (
	"os"
)

type Config struct {
	HTTPAddr string
	DB       DBConfig
	KServe   KServeConfig
	S3       S3Config
	JWT      JWTConfig
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
	Disabled        bool
}

type JWTConfig struct {
	Secret     string
	Expiration int
}

func Load() *Config {
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
			Region:          getEnv("S3_REGION", "us-east-1"),
			Endpoint:        getEnv("S3_ENDPOINT", ""),
			BaseURL:         getEnv("S3_BASE_URL", ""),
			AccessKeyID:     getEnv("AWS_ACCESS_KEY_ID", ""),
			SecretAccessKey: getEnv("AWS_SECRET_ACCESS_KEY", ""),
			Disabled:        getEnv("S3_BUCKET", "") == "",
		},
		JWT: JWTConfig{
			Secret:     getEnv("JWT_SECRET", "change-me-in-production"),
			Expiration: 24 * 7,
		},
	}
}

func getEnv(key, defaultVal string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return defaultVal
}
