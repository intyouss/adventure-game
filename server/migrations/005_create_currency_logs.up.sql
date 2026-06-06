CREATE TABLE IF NOT EXISTS currency_logs (
    id BIGSERIAL PRIMARY KEY,
    character_id BIGINT NOT NULL REFERENCES characters(id),
    currency VARCHAR(32) NOT NULL,
    amount BIGINT NOT NULL,
    reason VARCHAR(255) NOT NULL DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_currency_logs_character_id ON currency_logs(character_id);
CREATE INDEX IF NOT EXISTS idx_currency_logs_created_at ON currency_logs(created_at);
