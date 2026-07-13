package com.payflex.backend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Push PayFlex sans Firebase ni service cloud tiers.
 * <p>
 * Les alertes sont persistées dans {@code client_notifications} (voir
 * {@link ContributionWorkflowService#notifyClientInbox}). L'application mobile
 * interroge {@code POST /api/mobile/push/poll} et affiche des notifications
 * locales système ({@code flutter_local_notifications}).
 */
@Service
public class PushNotificationService {

    private static final Logger log = LoggerFactory.getLogger(PushNotificationService.class);

    /**
     * Compatibilité : ancien endpoint FCM — ignoré (modèle pull uniquement).
     */
    public void saveFcmToken(long userId, String token) {
        log.debug("saveFcmToken ignoré (push pull PayFlex) userId={}", userId);
    }

    /**
     * Journalise l'événement ; la livraison réelle passe par le poll mobile.
     */
    public void notifyUser(long userId, String title, String body) {
        if (userId <= 0) {
            return;
        }
        log.debug("Push pull en attente userId={} title={}", userId, title);
    }
}
