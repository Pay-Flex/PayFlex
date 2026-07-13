ALTER TABLE support_chat_messages
    ADD COLUMN attachment_url VARCHAR(512) NULL,
    ADD COLUMN attachment_kind VARCHAR(20) NULL,
    ADD COLUMN attachment_name VARCHAR(255) NULL,
    ADD COLUMN attachment_mime VARCHAR(120) NULL;
