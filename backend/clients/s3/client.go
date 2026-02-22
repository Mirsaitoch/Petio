package s3

import (
	"context"
	"fmt"
	"io"
	"net/url"
	"path"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
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
		baseURL = strings.TrimSuffix(cfg.Endpoint, "/") + "/" + cfg.Bucket
	}
	if baseURL == "" {
		baseURL = fmt.Sprintf("https://%s.s3.%s.amazonaws.com", cfg.Bucket, cfg.Region)
	}
	return &Client{client: client, bucket: cfg.Bucket, baseURL: strings.TrimSuffix(baseURL, "/")}
}

func (c *Client) Upload(ctx context.Context, key string, body io.Reader, contentType string) (publicURL string, err error) {
	if c == nil {
		return "", fmt.Errorf("s3 disabled")
	}
	_, err = c.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(c.bucket),
		Key:         aws.String(key),
		Body:        body,
		ContentType: aws.String(contentType),
	})
	if err != nil {
		return "", err
	}
	return c.PublicURL(key), nil
}

func (c *Client) PublicURL(key string) string {
	if c == nil {
		return ""
	}
	u, _ := url.Parse(c.baseURL)
	u.Path = path.Join(u.Path, key)
	return u.String()
}
