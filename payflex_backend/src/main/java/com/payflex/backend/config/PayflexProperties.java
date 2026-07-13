package com.payflex.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "payflex")
public class PayflexProperties {

    private Contributions contributions = new Contributions();
    private Paydunya paydunya = new Paydunya();
    private Push push = new Push();
    /** Seuil jours orange carnet pour alerte inbox client + agent (aligné dashboard admin). */
    private int catchupAlertThreshold = 5;
    /** Clé serveur pour le coffre identifiants (révélation admin). */
    private String vaultKey = "payflex-dev-vault-key-change-me";

    public Contributions getContributions() {
        return contributions;
    }

    public void setContributions(Contributions contributions) {
        this.contributions = contributions;
    }

    public Paydunya getPaydunya() {
        return paydunya;
    }

    public void setPaydunya(Paydunya paydunya) {
        this.paydunya = paydunya;
    }

    public Push getPush() {
        return push;
    }

    public void setPush(Push push) {
        this.push = push;
    }

    public int getCatchupAlertThreshold() {
        return catchupAlertThreshold;
    }

    public void setCatchupAlertThreshold(int catchupAlertThreshold) {
        this.catchupAlertThreshold = catchupAlertThreshold;
    }

    public String getVaultKey() {
        return vaultKey;
    }

    public void setVaultKey(String vaultKey) {
        this.vaultKey = vaultKey;
    }

    /**
     * Notifications push réelles PayFlex. Tout est optionnel : si rien n'est
     * configuré, l'app retombe sur le modèle « pull » (poll + inbox) existant.
     */
    public static class Push {
        /** Firebase Cloud Messaging pour le mobile (client + agent). */
        private Fcm fcm = new Fcm();
        /** Web Push (VAPID) pour les postes admin/support (navigateur). */
        private WebPush webPush = new WebPush();

        public Fcm getFcm() {
            return fcm;
        }

        public void setFcm(Fcm fcm) {
            this.fcm = fcm;
        }

        public WebPush getWebPush() {
            return webPush;
        }

        public void setWebPush(WebPush webPush) {
            this.webPush = webPush;
        }

        public static class Fcm {
            /**
             * Chemin absolu vers le fichier JSON du compte de service Firebase
             * (téléchargé depuis la console Firebase). Vide = FCM désactivé.
             */
            private String credentials = "";

            public String getCredentials() {
                return credentials;
            }

            public void setCredentials(String credentials) {
                this.credentials = credentials;
            }

            public boolean isConfigured() {
                return credentials != null && !credentials.isBlank();
            }
        }

        public static class WebPush {
            /** Clé publique VAPID (base64url) — exposée au navigateur. */
            private String publicKey = "";
            /** Clé privée VAPID (base64url) — secrète, jamais exposée. */
            private String privateKey = "";
            /** Sujet VAPID : mailto:contact ou URL du site. */
            private String subject = "mailto:support@payflex.app";

            public String getPublicKey() {
                return publicKey;
            }

            public void setPublicKey(String publicKey) {
                this.publicKey = publicKey;
            }

            public String getPrivateKey() {
                return privateKey;
            }

            public void setPrivateKey(String privateKey) {
                this.privateKey = privateKey;
            }

            public String getSubject() {
                return subject;
            }

            public void setSubject(String subject) {
                this.subject = subject;
            }

            public boolean isConfigured() {
                return publicKey != null && !publicKey.isBlank()
                    && privateKey != null && !privateKey.isBlank();
            }
        }
    }

    public static class Contributions {
        /** Heures avant validation auto des mobile money sans réponse agent (0 = désactivé). */
        private int autoValidateMobileMoneyHours = 24;
        /** Validation immédiate des collectes espèces saisies par l'agent mobile. */
        private boolean agentCashAutoValidate = true;

        public int getAutoValidateMobileMoneyHours() {
            return autoValidateMobileMoneyHours;
        }

        public void setAutoValidateMobileMoneyHours(int autoValidateMobileMoneyHours) {
            this.autoValidateMobileMoneyHours = autoValidateMobileMoneyHours;
        }

        public boolean isAgentCashAutoValidate() {
            return agentCashAutoValidate;
        }

        public void setAgentCashAutoValidate(boolean agentCashAutoValidate) {
            this.agentCashAutoValidate = agentCashAutoValidate;
        }
    }

    /**
     * PayDunya — passerelle mobile money unique (Flooz Moov, T-Money / Mixx by Yas, cartes),
     * via l'API « Checkout Invoice » (Paiement Avec Redirection). Repli gracieux : si les
     * clés sont absentes, {@link #isConfigured()} renvoie false et l'option est masquée.
     */
    public static class Paydunya {
        private boolean enabled = true;
        /** test = sandbox PayDunya (pas d'argent réel) ; live = production. */
        private String mode = "test";
        /** PAYDUNYA-MASTER-KEY (secrète, jamais loguée). */
        private String masterKey = "";
        /** PAYDUNYA-PRIVATE-KEY (secrète). */
        private String privateKey = "";
        /** PAYDUNYA-TOKEN (secret). */
        private String token = "";
        /** Clé publique (optionnelle, intégration côté client). */
        private String publicKey = "";
        /** URL publique du backend (callback IPN + return_url), ex. https://payflex.example.com */
        private String publicBaseUrl = "http://localhost:8088";

        public boolean isEnabled() {
            return enabled;
        }

        public void setEnabled(boolean enabled) {
            this.enabled = enabled;
        }

        public String getMode() {
            return mode;
        }

        public void setMode(String mode) {
            this.mode = mode;
        }

        public String getMasterKey() {
            return masterKey;
        }

        public void setMasterKey(String masterKey) {
            this.masterKey = masterKey;
        }

        public String getPrivateKey() {
            return privateKey;
        }

        public void setPrivateKey(String privateKey) {
            this.privateKey = privateKey;
        }

        public String getToken() {
            return token;
        }

        public void setToken(String token) {
            this.token = token;
        }

        public String getPublicKey() {
            return publicKey;
        }

        public void setPublicKey(String publicKey) {
            this.publicKey = publicKey;
        }

        public String getPublicBaseUrl() {
            return publicBaseUrl;
        }

        public void setPublicBaseUrl(String publicBaseUrl) {
            this.publicBaseUrl = publicBaseUrl;
        }

        public boolean isLive() {
            return "live".equalsIgnoreCase(mode) || "production".equalsIgnoreCase(mode);
        }

        /** Toutes les clés d'API sont présentes. */
        public boolean hasKeys() {
            return isFilled(masterKey) && isFilled(privateKey) && isFilled(token);
        }

        /** Activé ET clés présentes : condition d'utilisation réelle de PayDunya. */
        public boolean isConfigured() {
            return enabled && hasKeys();
        }

        public String apiBaseUrl() {
            return isLive()
                ? "https://app.paydunya.com/api/v1"
                : "https://app.paydunya.com/sandbox-api/v1";
        }

        private static boolean isFilled(String value) {
            return value != null && !value.isBlank();
        }
    }
}
