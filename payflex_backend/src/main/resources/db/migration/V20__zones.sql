-- Zones géographiques / commerciales : référentiel pour l’affectation des agents (remplace le texte libre).
CREATE TABLE IF NOT EXISTS zones (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(180) NOT NULL,
    description VARCHAR(500) NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_zones_name UNIQUE (name)
);

-- Remplir à partir des libellés déjà saisis sur les fiches agents
INSERT INTO zones (name, active)
SELECT DISTINCT TRIM(a.zone), TRUE
FROM agents a
WHERE a.zone IS NOT NULL AND TRIM(a.zone) <> ''
  AND NOT EXISTS (SELECT 1 FROM zones z WHERE z.name = TRIM(a.zone));

-- Au moins une zone si la base était vide côté agents
INSERT INTO zones (name, description, active)
SELECT 'Zone par défaut', 'Créée automatiquement — à renommer depuis l’admin.', TRUE
WHERE NOT EXISTS (SELECT 1 FROM zones);

ALTER TABLE agents
    ADD COLUMN zone_id BIGINT NULL,
    ADD CONSTRAINT fk_agents_zone FOREIGN KEY (zone_id) REFERENCES zones(id) ON DELETE RESTRICT;

CREATE INDEX idx_agents_zone_id ON agents(zone_id);

UPDATE agents a
INNER JOIN zones z ON z.name = TRIM(a.zone)
SET a.zone_id = z.id
WHERE a.zone IS NOT NULL AND TRIM(a.zone) <> '';

-- Fiches sans libellé : rattacher à la zone par défaut si elle existe seule
UPDATE agents a
SET a.zone_id = (SELECT id FROM zones WHERE name = 'Zone par défaut' LIMIT 1)
WHERE a.zone_id IS NULL
  AND EXISTS (SELECT 1 FROM zones WHERE name = 'Zone par défaut');

UPDATE agents a
INNER JOIN zones z ON z.id = a.zone_id
SET a.zone = z.name
WHERE a.zone_id IS NOT NULL;
