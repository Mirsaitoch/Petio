package http

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	httpSwagger "github.com/swaggo/http-swagger"

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
	jwtSecret string,
) http.Handler {
	r := chi.NewRouter()
	r.Use(chimiddleware.RealIP)
	r.Use(chimiddleware.Logger)
	r.Use(chimiddleware.Recoverer)
	r.Use(corsMiddleware())

	r.Get("/swagger/*", httpSwagger.WrapHandler)

	r.Route("/v1", func(r chi.Router) {
		r.Post("/auth/login", auth.Login)
		r.Post("/auth/register", auth.Register)
		r.Post("/auth/refresh", auth.RefreshToken)

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

			r.Post("/chat/send", chat.Send)

			r.Post("/upload/pet-photo", upload.UploadPetPhoto)
			r.Post("/upload/post-image", upload.UploadPostImage)
			r.Post("/upload/avatar", upload.UploadAvatar)

			r.Get("/profile", profile.Get)
			r.Put("/profile", profile.Update)
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
