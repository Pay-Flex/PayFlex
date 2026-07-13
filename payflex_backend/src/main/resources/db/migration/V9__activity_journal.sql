-- Journal d'activité lisible : une ligne = une phrase pour l'équipe, sans codes techniques à l'affichage.
CREATE TABLE IF NOT EXISTS activity_journal (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    profile VARCHAR(32) NOT NULL,
    actor_display VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_activity_journal_created (created_at DESC),
    INDEX idx_activity_journal_profile (profile)
);

-- Reprise des anciennes entrées techniques (audit admin) en langage simplifié
INSERT INTO activity_journal (profile, actor_display, message, created_at)
SELECT
    'equipe',
    admin_username,
    CONCAT(
        CASE action_type
            WHEN 'CREATE' THEN 'Une création a été enregistrée dans l''administration. '
            WHEN 'UPDATE' THEN 'Une fiche a été modifiée depuis l''administration. '
            WHEN 'DELETE' THEN 'Une suppression a été effectuée depuis l''administration. '
            WHEN 'UPDATE_STATUS' THEN 'Un statut a été mis à jour depuis l''administration. '
            WHEN 'DECIDE' THEN 'Une décision a été prise sur une demande d''inscription. '
            ELSE CONCAT('Une opération administrative a été enregistrée. ')
        END,
        COALESCE(NULLIF(TRIM(details), ''), 'Aucun détail supplémentaire.')
    ),
    created_at
FROM admin_audit_logs a
WHERE (SELECT COUNT(*) FROM activity_journal) = 0;
