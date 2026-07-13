-- Planning hebdomadaire agent (notes libres + détail par jour en JSON).
ALTER TABLE agents ADD COLUMN weekly_schedule_json TEXT NULL;
