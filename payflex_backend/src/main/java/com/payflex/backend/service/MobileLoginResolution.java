package com.payflex.backend.service;

import java.util.Map;

/**
 * Résultat d'une tentative de connexion mobile (profil ou message d'erreur explicite).
 */
public record MobileLoginResolution(
    Map<String, Object> profile,
    String failureMessage,
    String errorCode
) {
    public static final String CODE_AMBIGUOUS = "ambiguous_identity";
    public static final String CODE_INVALID_CREDENTIALS = "invalid_credentials";
    /** Nom, prénom, numéro ou e-mail introuvable. */
    public static final String CODE_INVALID_IDENTIFIER = "invalid_identifier";
    /** Compte trouvé mais mot de passe / code PIN incorrect. */
    public static final String CODE_INVALID_SECRET = "invalid_secret";

    public static MobileLoginResolution success(Map<String, Object> profile) {
        return new MobileLoginResolution(profile, null, null);
    }

    public static MobileLoginResolution fail(String message, String errorCode) {
        return new MobileLoginResolution(null, message, errorCode);
    }

    public boolean isSuccess() {
        return profile != null;
    }
}
