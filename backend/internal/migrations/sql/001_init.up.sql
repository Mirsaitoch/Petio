-- ========== USERS ==========
CREATE TABLE IF NOT EXISTS users (
                                     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    name TEXT NOT NULL DEFAULT '',
    username TEXT NOT NULL DEFAULT '',
    avatar TEXT,
    bio TEXT NOT NULL DEFAULT '',
    join_date DATE NOT NULL DEFAULT CURRENT_DATE
    );

-- ========== PETS ==========
CREATE TABLE IF NOT EXISTS pets (
                                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    species TEXT NOT NULL,
    breed TEXT NOT NULL,
    age INT NOT NULL DEFAULT 0,
    weight DOUBLE PRECISION NOT NULL DEFAULT 0,
    photo TEXT,
    birth_date DATE NOT NULL,
    features TEXT[]
    );

CREATE TABLE IF NOT EXISTS vaccinations (
                                            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    date DATE NOT NULL,
    next_date DATE NOT NULL
    );

-- ========== REMINDERS ==========
CREATE TABLE IF NOT EXISTS reminders (
                                         id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    pet_name TEXT NOT NULL,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    date DATE NOT NULL,
    time TEXT NOT NULL,
    completed BOOLEAN NOT NULL DEFAULT FALSE
    );

-- ========== WEIGHT ==========
CREATE TABLE IF NOT EXISTS weight_records (
                                              pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    weight DOUBLE PRECISION NOT NULL,
    PRIMARY KEY (pet_id, date)
    );

-- ========== HEALTH DIARY ==========
CREATE TABLE IF NOT EXISTS health_diary (
                                            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    note TEXT NOT NULL
    );

-- ========== ARTICLES ==========
CREATE TABLE IF NOT EXISTS articles (
                                        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT NOT NULL,
    image TEXT,
    pet_type TEXT NOT NULL,
    care_type TEXT NOT NULL,
    read_time INT NOT NULL DEFAULT 0
    );

-- ========== POSTS & SOCIAL ==========
CREATE TABLE IF NOT EXISTS posts (
                                     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    author TEXT NOT NULL,
    avatar TEXT,
    content TEXT NOT NULL,
    image TEXT,
    likes INT NOT NULL DEFAULT 0,
    club TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

CREATE TABLE IF NOT EXISTS post_likes (
                                          post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, user_id)
    );

CREATE TABLE IF NOT EXISTS comments (
                                        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    author TEXT NOT NULL,
    avatar TEXT,
    content TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

-- ========== AUTH TOKENS ==========
CREATE TABLE IF NOT EXISTS refresh_tokens (
                                              id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL
    );

CREATE TABLE IF NOT EXISTS password_reset_tokens (
                                                     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL
    );

-- ========== INDEXES ==========
CREATE INDEX IF NOT EXISTS idx_pets_user_id ON pets(user_id);
CREATE INDEX IF NOT EXISTS idx_reminders_user_id ON reminders(user_id);
CREATE INDEX IF NOT EXISTS idx_reminders_pet_id ON reminders(pet_id);
CREATE INDEX IF NOT EXISTS idx_health_diary_user_pet ON health_diary(user_id, pet_id);
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_token_hash ON refresh_tokens(token_hash);
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_token_hash ON password_reset_tokens(token_hash);
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user_id ON password_reset_tokens(user_id);