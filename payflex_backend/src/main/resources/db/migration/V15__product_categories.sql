CREATE TABLE IF NOT EXISTS product_categories (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(64) NOT NULL UNIQUE,
    label VARCHAR(120) NOT NULL,
    sort_order INT NOT NULL DEFAULT 100,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO product_categories (code, label, sort_order) VALUES
    ('couture', 'Couture', 10),
    ('coiffure', 'Coiffure', 20),
    ('menuiserie', 'Menuiserie', 30),
    ('maconnerie', 'Maçonnerie', 40),
    ('plomberie', 'Plomberie', 50),
    ('electricite', 'Électricité bâtiment', 60),
    ('soudure', 'Soudure', 70),
    ('mecanique', 'Mécanique', 80),
    ('froid_clim', 'Froid et climatisation', 90),
    ('autre', 'Autres équipements', 999);

ALTER TABLE products
    ADD COLUMN category_id BIGINT NULL AFTER category;

UPDATE products p
INNER JOIN product_categories pc ON LOWER(TRIM(p.category)) = LOWER(TRIM(pc.label))
SET p.category_id = pc.id;

UPDATE products p
JOIN product_categories pc ON pc.code = 'autre'
SET p.category_id = pc.id
WHERE p.category_id IS NULL;

ALTER TABLE products
    MODIFY COLUMN category_id BIGINT NOT NULL;

ALTER TABLE products
    ADD CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES product_categories (id);
