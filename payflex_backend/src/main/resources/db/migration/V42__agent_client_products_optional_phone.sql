-- Téléphone optionnel pour clients inscrits par agent (sans smartphone)
ALTER TABLE users MODIFY phone VARCHAR(30) NULL;
ALTER TABLE registration_requests MODIFY phone VARCHAR(40) NULL;

CREATE TABLE IF NOT EXISTS client_product_selections (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    selected_by_agent_user_id BIGINT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_cps_user_product (user_id, product_id),
    CONSTRAINT fk_cps_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_cps_product FOREIGN KEY (product_id) REFERENCES products(id),
    CONSTRAINT fk_cps_agent FOREIGN KEY (selected_by_agent_user_id) REFERENCES users(id)
);

CREATE INDEX idx_cps_user ON client_product_selections(user_id);
