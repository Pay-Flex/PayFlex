-- Phase 4.2 : clôture carnet / solde puis livraison outil.
CREATE TABLE IF NOT EXISTS client_product_deliveries (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'awaiting_closure',
    total_validated DECIMAL(14, 2) NOT NULL DEFAULT 0,
    product_price DECIMAL(14, 2) NOT NULL,
    catchup_days_snapshot INT NOT NULL DEFAULT 0,
    admin_note TEXT NULL,
    closed_by VARCHAR(150) NULL,
    closed_at TIMESTAMP NULL,
    delivered_by VARCHAR(150) NULL,
    delivered_at TIMESTAMP NULL,
    stock_reference VARCHAR(80) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_cpd_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_cpd_product FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE INDEX IF NOT EXISTS idx_cpd_status ON client_product_deliveries (status);
CREATE INDEX IF NOT EXISTS idx_cpd_user ON client_product_deliveries (user_id);
