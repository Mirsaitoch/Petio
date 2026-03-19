package email

import (
	"fmt"
	"log"
	"net/smtp"

	"petio/backend/internal/config"
)

type Sender struct {
	cfg config.SMTPConfig
}

func NewSender(cfg config.SMTPConfig) *Sender {
	if !cfg.Configured() {
		return nil
	}
	return &Sender{cfg: cfg}
}

func (s *Sender) Send(to, subject, htmlBody string) error {
	addr := fmt.Sprintf("%s:%s", s.cfg.Host, s.cfg.Port)

	var auth smtp.Auth
	if s.cfg.Username != "" {
		auth = smtp.PlainAuth("", s.cfg.Username, s.cfg.Password, s.cfg.Host)
	}

	msg := fmt.Sprintf(
		"From: %s\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/html; charset=\"UTF-8\"\r\n\r\n%s",
		s.cfg.From, to, subject, htmlBody,
	)

	if err := smtp.SendMail(addr, auth, s.cfg.From, []string{to}, []byte(msg)); err != nil {
		return fmt.Errorf("smtp send: %w", err)
	}
	log.Printf("email sent to %s: %s", to, subject)
	return nil
}
