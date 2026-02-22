package domain

type Pet struct {
	ID           string        `json:"id" db:"id"`
	Name         string        `json:"name" db:"name"`
	Species      string        `json:"species" db:"species"`
	Breed        string        `json:"breed" db:"breed"`
	Age          string        `json:"age" db:"age"`
	Weight       float64       `json:"weight" db:"weight"`
	Photo        *string       `json:"photo,omitempty" db:"photo"`
	BirthDate    string        `json:"birthDate" db:"birth_date"`
	Vaccinations []Vaccination `json:"vaccinations" db:"-"`
	Features     []string      `json:"features" db:"-"`
	UserID       string        `json:"-" db:"user_id"`
}

type Vaccination struct {
	ID       string `json:"id" db:"id"`
	Name     string `json:"name" db:"name"`
	Date     string `json:"date" db:"date"`
	NextDate string `json:"nextDate" db:"next_date"`
}

type Reminder struct {
	ID        string       `json:"id" db:"id"`
	PetID     string       `json:"petId" db:"pet_id"`
	PetName   string       `json:"petName" db:"pet_name"`
	Type      ReminderType `json:"type" db:"type"`
	Title     string       `json:"title" db:"title"`
	Date      string       `json:"date" db:"date"`
	Time      string       `json:"time" db:"time"`
	Completed bool         `json:"completed" db:"completed"`
	UserID    string       `json:"-" db:"user_id"`
}

type ReminderType string

const (
	ReminderFeeding    ReminderType = "feeding"
	ReminderVaccination ReminderType = "vaccination"
	ReminderDeworming  ReminderType = "deworming"
	ReminderGrooming   ReminderType = "grooming"
)

type WeightRecord struct {
	Date   string  `json:"date" db:"date"`
	Weight float64 `json:"weight" db:"weight"`
}

type HealthDiaryEntry struct {
	ID     string `json:"id" db:"id"`
	PetID  string `json:"petId" db:"pet_id"`
	Date   string `json:"date" db:"date"`
	Note   string `json:"note" db:"note"`
	UserID string `json:"-" db:"user_id"`
}

type Article struct {
	ID          string  `json:"id" db:"id"`
	Title       string  `json:"title" db:"title"`
	Description string  `json:"description" db:"description"`
	Category    string  `json:"category" db:"category"`
	Image       *string `json:"image,omitempty" db:"image"`
	PetType     string  `json:"petType" db:"pet_type"`
	CareType    string  `json:"careType" db:"care_type"`
	ReadTime    string  `json:"readTime" db:"read_time"`
}

type Comment struct {
	ID        string  `json:"id" db:"id"`
	Author    string  `json:"author" db:"author"`
	Avatar    *string `json:"avatar,omitempty" db:"avatar"`
	Content   string  `json:"content" db:"content"`
	Timestamp string  `json:"timestamp" db:"timestamp"`
	PostID    string  `json:"-" db:"post_id"`
}

type Post struct {
	ID        string    `json:"id" db:"id"`
	Author    string    `json:"author" db:"author"`
	Avatar    *string   `json:"avatar,omitempty" db:"avatar"`
	Content   string    `json:"content" db:"content"`
	Image     *string   `json:"image,omitempty" db:"image"`
	Likes     int       `json:"likes" db:"likes"`
	Comments  []Comment `json:"comments" db:"-"`
	Club      string    `json:"club" db:"club"`
	Timestamp string    `json:"timestamp" db:"timestamp"`
	Liked     bool      `json:"liked" db:"-"`
	UserID    string    `json:"-" db:"user_id"`
}

type UserProfile struct {
	Name       string  `json:"name" db:"name"`
	Username   string  `json:"username" db:"username"`
	Avatar     *string `json:"avatar,omitempty" db:"avatar"`
	Bio        string  `json:"bio" db:"bio"`
	PetsCount  int     `json:"petsCount" db:"pets_count"`
	PostsCount int     `json:"postsCount" db:"posts_count"`
	JoinDate   string  `json:"joinDate" db:"join_date"`
	UserID     string  `json:"-" db:"user_id"`
}

type User struct {
	ID       string `json:"id" db:"id"`
	Email    string `json:"email" db:"email"`
	Password string `json:"-" db:"password"`
}
