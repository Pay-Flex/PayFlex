ALTER TABLE products
    ADD COLUMN image_main_path VARCHAR(512) NULL AFTER image_url,
    ADD COLUMN image_detail_1_path VARCHAR(512) NULL,
    ADD COLUMN image_detail_2_path VARCHAR(512) NULL,
    ADD COLUMN featured BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE products p
JOIN (SELECT MIN(id) AS mid FROM products) t ON p.id = t.mid
SET p.featured = TRUE;
