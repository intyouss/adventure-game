CREATE TABLE IF NOT EXISTS characters (
    id            BIGSERIAL PRIMARY KEY,
    account_id    BIGINT UNIQUE NOT NULL REFERENCES accounts(id),
    class         VARCHAR(20) NOT NULL DEFAULT 'warrior',
    nickname      VARCHAR(50) NOT NULL DEFAULT '',
    level         INT NOT NULL DEFAULT 1,
    exp           BIGINT NOT NULL DEFAULT 0,
    gold          BIGINT NOT NULL DEFAULT 0,
    skill_tickets BIGINT NOT NULL DEFAULT 0,
    equipments    JSONB NOT NULL DEFAULT '[]'::jsonb,
    equipped      JSONB NOT NULL DEFAULT '{}'::jsonb,
    skill_slots   JSONB NOT NULL DEFAULT '{"1":"","2":"","3":"","4":""}'::jsonb,
    created_at    TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at    TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_characters_account_id ON characters(account_id);
