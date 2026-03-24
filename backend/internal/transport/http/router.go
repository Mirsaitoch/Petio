// internal/transport/http/router.go
package http

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	httpSwagger "github.com/swaggo/http-swagger"
	"go.uber.org/zap"

	"petio/backend/internal/transport/http/handlers"
	"petio/backend/internal/transport/http/handlers/middleware"
)

func NewRouter(
	auth *handlers.AuthHandler,
	pet *handlers.PetHandler,
	reminder *handlers.ReminderHandler,
	weight *handlers.WeightHandler,
	diary *handlers.DiaryHandler,
	article *handlers.ArticleHandler,
	post *handlers.PostHandler,
	chat *handlers.ChatHandler,
	profile *handlers.ProfileHandler,
	upload *handlers.UploadHandler,
	shelter *handlers.ShelterHandler,
	jwtSecret string,
	log *zap.Logger,
) http.Handler {
	r := chi.NewRouter()
	r.Use(chimiddleware.RealIP)
	r.Use(chimiddleware.RequestID)
	r.Use(middleware.RequestLog(log.Named("http")))
	r.Use(middleware.PrometheusMetrics)
	r.Use(chimiddleware.Recoverer)
	r.Use(corsMiddleware())

	r.Handle("/metrics", promhttp.Handler())

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})

	r.Get("/swagger/*", httpSwagger.WrapHandler)

	r.Route("/v1", func(r chi.Router) {
		r.Post("/auth/login", auth.Login)
		r.Post("/auth/refresh", auth.RefreshToken)
		r.Post("/auth/device", auth.LoginByDevice)
		r.Get("/auth/device/accounts", auth.ListDeviceAccounts)
		r.Post("/auth/device/switch", auth.SwitchDeviceAccount)
		r.Post("/auth/forgot-password", auth.ForgotPassword)
		r.Post("/auth/reset-password", auth.ResetPassword)

		r.Group(func(r chi.Router) {
			r.Use(middleware.JWT(jwtSecret))
			r.Route("/pets", func(r chi.Router) {
				r.Get("/", pet.List)
				r.Post("/", pet.Create)
				r.Get("/{id}", pet.Get)
				r.Put("/{id}", pet.Update)
				r.Delete("/{id}", pet.Delete)
				r.Get("/{petId}/weight", weight.List)
				r.Get("/{petId}/weight/{date}", weight.Get)
				r.Post("/{petId}/weight", weight.Add)
				r.Put("/{petId}/weight/{date}", weight.Update)
				r.Delete("/{petId}/weight/{date}", weight.Delete)
				r.Get("/{petId}/diary", diary.List)
				r.Post("/{petId}/diary", diary.Create)
			})
			r.Get("/diary/{id}", diary.Get)
			r.Put("/diary/{id}", diary.Update)
			r.Delete("/diary/{id}", diary.Delete)

			r.Route("/reminders", func(r chi.Router) {
				r.Get("/", reminder.List)
				r.Post("/", reminder.Create)
				r.Get("/{id}", reminder.Get)
				r.Put("/{id}", reminder.Update)
				r.Delete("/{id}", reminder.Delete)
			})

			r.Route("/articles", func(r chi.Router) {
				r.Get("/", article.List)
				r.Post("/", article.Create)
				r.Get("/{id}", article.Get)
				r.Put("/{id}", article.Update)
				r.Delete("/{id}", article.Delete)
			})

			r.Route("/posts", func(r chi.Router) {
				r.Get("/", post.ListPaginated)
				r.Get("/all", post.List)
				r.Post("/", post.Create)
				r.Get("/{id}", post.Get)
				r.Put("/{id}", post.Update)
				r.Delete("/{id}", post.Delete)
				r.Post("/{id}/like", post.Like)
				r.Post("/{postId}/comments", post.AddComment)
			})

			r.Route("/chats", func(r chi.Router) {
				r.Get("/", chat.ListChats)
				r.Post("/", chat.CreateChat)
				r.Get("/stats", chat.GetStats)

				r.Get("/{id}", chat.GetChat)
				r.Patch("/{id}", chat.UpdateChatTitle)
				r.Delete("/{id}", chat.DeleteChat)

				r.Get("/{id}/messages", chat.GetMessages)
				r.Post("/{id}/messages", chat.SendMessage)
			})

			r.Post("/upload/pet-photo", upload.UploadPetPhoto)
			r.Post("/upload/post-image", upload.UploadPostImage)
			r.Post("/upload/avatar", upload.UploadAvatar)

			r.Get("/profile", profile.Get)
			r.Put("/profile", profile.Update)

			r.Post("/auth/link-email", auth.LinkEmail)
			r.Post("/auth/verify-email", auth.VerifyEmail)

			r.Route("/shelters", func(r chi.Router) {
				r.Get("/", shelter.List)
				r.Post("/", shelter.Create)
				r.Get("/{id}", shelter.Get)
				r.Put("/{id}", shelter.Update)
				r.Delete("/{id}", shelter.Delete)
			})

		})
	})

	return r
}

func corsMiddleware() func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
