package com.payflex.backend.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Initialisation Firebase Admin SDK pour le push mobile (FCM).
 * <p>
 * Entièrement gardée : si {@code payflex.push.fcm.credentials} est vide ou pointe
 * vers un fichier absent/invalide, aucun bean {@link FirebaseMessaging} n'est créé
 * et l'application démarre normalement (repli sur le poll mobile existant).
 */
@Configuration
public class FirebaseConfig {

    private static final Logger log = LoggerFactory.getLogger(FirebaseConfig.class);

    /**
     * Retourne un {@link FirebaseMessaging} prêt à l'emploi, ou {@code null} si Firebase
     * n'est pas configuré. Les services consommateurs doivent tolérer {@code null}.
     */
    @Bean
    public FirebaseMessaging firebaseMessaging(PayflexProperties properties) {
        PayflexProperties.Push.Fcm fcm = properties.getPush().getFcm();
        if (fcm == null || !fcm.isConfigured()) {
            log.info("FCM désactivé (payflex.push.fcm.credentials non défini) — repli sur le poll mobile.");
            return null;
        }
        Path path = Path.of(fcm.getCredentials().trim());
        if (!Files.isReadable(path)) {
            log.warn("FCM désactivé : fichier d'identifiants Firebase introuvable/illisible ({}).", path);
            return null;
        }
        try (InputStream credentials = new FileInputStream(path.toFile())) {
            FirebaseApp app;
            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(credentials))
                    .build();
                app = FirebaseApp.initializeApp(options);
                log.info("Firebase Admin SDK initialisé — push FCM actif.");
            } else {
                app = FirebaseApp.getInstance();
            }
            return FirebaseMessaging.getInstance(app);
        } catch (Exception ex) {
            log.warn("FCM désactivé : échec d'initialisation Firebase ({}). Repli sur le poll mobile.", ex.getMessage());
            return null;
        }
    }
}
