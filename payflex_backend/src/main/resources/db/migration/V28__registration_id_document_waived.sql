ALTER TABLE registration_requests
    ADD COLUMN id_document_waived BOOLEAN NOT NULL DEFAULT FALSE AFTER id_document_path;
