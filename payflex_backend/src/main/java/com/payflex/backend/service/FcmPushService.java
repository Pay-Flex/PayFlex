package com.payflex.backend.service;

import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.Notification;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Envoi de notifications push mobiles via Firebase Cloud Messaging.
 * <p>
 * Entièrement gardé : si Firebase n'est pas configuré ({@link FirebaseMessaging}
 * absent), les appels sont ignorés silencieusement (repli sur le poll mobile).
 */
@Service
public class FcmPushService {

    private static final Logger log = LoggerFactory.getLogger(FcmPushService.class);

    private final ObjectProvider<FirebaseMessaging> messagingProvider;
    private final DeviceTokenService deviceTokenService;

    public FcmPushService(
        ObjectProvider<FirebaseMessaging> messagingProvider,
        DeviceTokenService deviceTokenService
    ) {
        this.messagingProvider = messagingProvider;
        this.deviceTokenService = deviceTokenService;
    }

    public boolean isEnabled() {
        return messagingProvider.getIfAvailable() != null;
    }

    /**
     * Envoie une notification push à tous les appareils d'un utilisateur.
     * Non bloquant (asynchrone) pour ne pas ralentir l'INSERT inbox appelant.
     */
    @Async
    public void sendToUser(long userId, String title, String body, Map<String, String> data) {
        FirebaseMessaging messaging = messagingProvider.getIfAvailable();
        if (messaging == null || userId <= 0 || title == null || title.isBlank()) {
            return;
        }
        List<String> tokens = deviceTokenService.tokensForUser(userId);
        if (tokens.isEmpty()) {
            return;
        }
        String safeBody = body == null ? "" : (body.length() > 900 ? body.substring(0, 900) : body);
        for (String token : tokens) {
            sendSingle(messaging, token, title.trim(), safeBody, data);
        }
    }

    private void sendSingle(FirebaseMessaging messaging, String token, String title, String body, Map<String, String> data) {
        Map<String, String> payload = new HashMap<>();
        if (data != null) {
            data.forEach((k, v) -> {
                if (k != null && v != null) {
                    payload.put(k, v);
                }
            });
        }
        Message message = Message.builder()
            .setToken(token)
            .setNotification(Notification.builder()
                .setTitle(title)
                .setBody(body)
                .build())
            .putAllData(payload)
            .setAndroidConfig(AndroidConfig.builder()
                .setPriority(AndroidConfig.Priority.HIGH)
                .setNotification(AndroidNotification.builder()
                    .setChannelId("payflex_alerts_v2")
                    .setIcon("ic_stat_payflex")
                    .setColor("#F9A825")
                    .build())
                .build())
            .build();
        try {
            messaging.send(message);
        } catch (FirebaseMessagingException ex) {
            MessagingErrorCode code = ex.getMessagingErrorCode();
            if (code == MessagingErrorCode.UNREGISTERED || code == MessagingErrorCode.INVALID_ARGUMENT) {
                deviceTokenService.removeInvalidToken(token);
            } else {
                log.warn("Échec envoi FCM (code={}) : {}", code, ex.getMessage());
            }
        } catch (Exception ex) {
            log.warn("Échec envoi FCM : {}", ex.getMessage());
        }
    }
}
