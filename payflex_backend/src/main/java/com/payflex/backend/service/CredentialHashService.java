package com.payflex.backend.service;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

/**
 * Hash BCrypt des identifiants (admin web + PIN mobile unique).
 */
@Service
public class CredentialHashService {

    private final PasswordEncoder passwordEncoder;

    public CredentialHashService(PasswordEncoder passwordEncoder) {
        this.passwordEncoder = passwordEncoder;
    }

    public boolean isBcryptHash(String stored) {
        if (stored == null || stored.length() < 7) {
            return false;
        }
        return stored.startsWith("$2a$") || stored.startsWith("$2b$") || stored.startsWith("$2y$");
    }

    public boolean isMobilePinFormat(String raw) {
        String p = raw == null ? "" : raw.trim();
        return p.length() >= 4 && p.length() <= 12 && p.chars().allMatch(Character::isDigit);
    }

    /** Code PIN (4–12 chiffres) ou mot de passe (8–64 caractères) pour l’app mobile. */
    public void validateMobileCredential(String raw) {
        String p = raw == null ? "" : raw.trim();
        if (p.length() < 4) {
            throw new IllegalArgumentException("Mot de passe ou code PIN requis (minimum 4 caractères).");
        }
        if (isMobilePinFormat(p) || (p.length() >= 8 && p.length() <= 64)) {
            return;
        }
        throw new IllegalArgumentException(
            "Utilisez un code PIN (4 à 12 chiffres) ou un mot de passe (8 à 64 caractères)."
        );
    }

    public void validateMobilePin(String rawPin) {
        validateMobileCredential(rawPin);
        if (!isMobilePinFormat(rawPin)) {
            throw new IllegalArgumentException("Le code PIN doit contenir 4 à 12 chiffres.");
        }
    }

    public String hashMobileCredential(String raw) {
        validateMobileCredential(raw);
        return passwordEncoder.encode(raw.trim());
    }

    public String hashMobilePin(String rawPin) {
        validateMobilePin(rawPin);
        return passwordEncoder.encode(rawPin.trim());
    }

    public String hashAdminPassword(String rawPassword) {
        if (rawPassword == null || rawPassword.trim().length() < 8) {
            throw new IllegalArgumentException("Le mot de passe administrateur doit contenir au moins 8 caractères.");
        }
        return passwordEncoder.encode(rawPassword.trim());
    }

    /**
     * Vérifie le mot de passe ou le PIN saisi (BCrypt ou ancien texte clair en migration).
     */
    public boolean matchesMobileCredential(String raw, String stored) {
        return matchesMobilePin(raw, stored);
    }

    public boolean matchesMobilePin(String rawPin, String stored) {
        if (rawPin == null || stored == null || stored.isBlank()) {
            return false;
        }
        String raw = rawPin.trim();
        if (isBcryptHash(stored)) {
            return passwordEncoder.matches(raw, stored);
        }
        return constantTimeEquals(raw, stored.trim());
    }

    public boolean matchesAdminPassword(String rawPassword, String stored) {
        if (rawPassword == null || stored == null || stored.isBlank()) {
            return false;
        }
        String raw = rawPassword.trim();
        if (stored.startsWith("{noop}")) {
            return constantTimeEquals(raw, stored.substring("{noop}".length()));
        }
        if (stored.startsWith("{bcrypt}")) {
            return passwordEncoder.matches(raw, stored.substring("{bcrypt}".length()));
        }
        if (isBcryptHash(stored)) {
            return passwordEncoder.matches(raw, stored);
        }
        return constantTimeEquals(raw, stored.trim());
    }

    /** Extrait le mot de passe en clair d’un enregistrement Spring {@code {noop}…}. */
    public String extractNoopPassword(String stored) {
        if (stored != null && stored.startsWith("{noop}")) {
            return stored.substring("{noop}".length());
        }
        return stored;
    }

    private static boolean constantTimeEquals(String a, String b) {
        byte[] x = a.getBytes(StandardCharsets.UTF_8);
        byte[] y = b.getBytes(StandardCharsets.UTF_8);
        return MessageDigest.isEqual(x, y);
    }
}
