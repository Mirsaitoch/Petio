package domain

type PostsRequest struct {
	Limit    int     `json:"limit"`     // сколько постов загрузить
	AfterID  *string `json:"after_id"`  // ID поста, после которого грузить (для старых)
	BeforeID *string `json:"before_id"` // ID поста, до которого грузить (для новых)
	Club     *string `json:"club"`      // фильтр по клубу
}

type PostsResponse struct {
	Posts   []Post `json:"posts"`
	HasMore bool   `json:"has_more"` // есть ли еще посты внизу
	HasNew  bool   `json:"has_new"`  // есть ли новые посты сверху
}
