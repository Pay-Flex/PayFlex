ALTER TABLE users
  ADD COLUMN adhesion_fedapay_transaction_id VARCHAR(64) NULL AFTER adhesion_collected_by_user_id;

CREATE INDEX idx_users_adhesion_fedapay_tx ON users (adhesion_fedapay_transaction_id);
