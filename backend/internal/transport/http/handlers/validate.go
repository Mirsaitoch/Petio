package handlers

import (
	"regexp"
	"strings"
)

var emailRegexp = regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)

const minPasswordLength = 6

// ValidateEmail returns true if s looks like an email.
func ValidateEmail(s string) bool {
	return len(s) > 0 && len(s) <= 254 && emailRegexp.MatchString(strings.TrimSpace(s))
}

// ValidatePassword returns an error message if password is too short, or empty string if ok.
func ValidatePassword(pass string) string {
	if len(pass) < minPasswordLength {
		return "password must be at least 6 characters"
	}
	return ""
}
