package s3

import (
	"bytes"
	"context"
	"crypto/md5"
	"encoding/base64"
	"fmt"
	"net/url"
	"path"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
)

type Config struct {
	Bucket          string
	Region          string
	Endpoint        string
	BaseURL         string
	AccessKeyID     string
	SecretAccessKey string
}

type Client struct {
	client  *s3.Client
	bucket  string
	baseURL string
}

func New(cfg Config) *Client {
	if cfg.Bucket == "" {
		return nil
	}
	awsCfg := aws.Config{Region: cfg.Region}
	if cfg.AccessKeyID != "" && cfg.SecretAccessKey != "" {
		awsCfg.Credentials = credentials.NewStaticCredentialsProvider(
			cfg.AccessKeyID, cfg.SecretAccessKey, "",
		)
	}
	opts := []func(*s3.Options){}
	if cfg.Endpoint != "" {
		opts = append(opts, func(o *s3.Options) {
			o.BaseEndpoint = aws.String(cfg.Endpoint)
			o.UsePathStyle = true
		})
	}
	client := s3.NewFromConfig(awsCfg, opts...)
	baseURL := cfg.BaseURL
	if baseURL == "" && cfg.Endpoint != "" {
		// Формат Yandex Object Storage: https://storage.yandexcloud.net/<bucket>
		baseURL = strings.TrimSuffix(cfg.Endpoint, "/") + "/" + cfg.Bucket
	}
	if baseURL == "" {
		baseURL = fmt.Sprintf("https://%s.s3.%s.amazonaws.com", cfg.Bucket, cfg.Region)
	}
	// Убираем завершающий слэш, чтобы PublicURL собирал path как /bucket/key
	return &Client{client: client, bucket: cfg.Bucket, baseURL: strings.TrimSuffix(baseURL, "/")}
}

// Upload загружает объект в S3. Передаёт Content-MD5 (для Yandex Object Storage при блокировках версий)
// и ACL public-read, чтобы ссылка открывалась в браузере.
func (c *Client) Upload(ctx context.Context, key string, body []byte, contentType string) (publicURL string, err error) {
	if c == nil {
		return "", fmt.Errorf("s3 disabled")
	}
	hash := md5.Sum(body)
	contentMD5 := base64.StdEncoding.EncodeToString(hash[:])

	_, err = c.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(c.bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader(body),
		ContentType: aws.String(contentType),
		ContentMD5:  aws.String(contentMD5),
		ACL:         types.ObjectCannedACLPublicRead,
	})
	if err != nil {
		return "", err
	}
	return c.PublicURL(key), nil
}

// PublicURL возвращает публичный URL объекта в формате Yandex Object Storage:
// https://storage.yandexcloud.net/<bucket>/<key>
func (c *Client) PublicURL(key string) string {
	if c == nil {
		return ""
	}
	key = strings.TrimPrefix(key, "/")
	u, _ := url.Parse(c.baseURL)
	// Собираем path явно: /<bucket>/<key>, чтобы не терять бакет при path.Join с ключом, начинающимся с /
	u.Path = "/" + path.Join(c.bucket, key)
	return u.String()
}
