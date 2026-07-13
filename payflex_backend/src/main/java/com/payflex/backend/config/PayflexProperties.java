package com.payflex.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "payflex")
public class PayflexProperties {

    private Contributions contributions = new Contributions();
    private Fedapay fedapay = new Fedapay();
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

    public Fedapay getFedapay() {
        return fedapay;
    }

    public void setFedapay(Fedapay fedapay) {
        this.fedapay = fedapay;
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

    public static class Fedapay {
        private boolean enabled = true;
        /** true = page PayFlex locale, sans appel API FedaPay (défaut si pas de clé API). */
        private boolean simulate = true;
        private boolean sandbox = true;
        private String apiKey = "";
        /** Clé publique (pk_…) — optionnelle, pour intégration client ; ne pas logger. */
        private String publicKey = "";
        private String webhookSecret = "";
        /** URL publique du backend (webhook + callback), ex. https://payflex.example.com */
        private String publicBaseUrl = "http://localhost:8088";

        public boolean isEnabled() {
            return enabled;
        }

        public void setEnabled(boolean enabled) {
            this.enabled = enabled;
        }

        public boolean isSimulate() {
            return simulate;
        }

        public void setSimulate(boolean simulate) {
            this.simulate = simulate;
        }

        public boolean isSandbox() {
            return sandbox;
        }

        public void setSandbox(boolean sandbox) {
            this.sandbox = sandbox;
        }

        public String getApiKey() {
            return apiKey;
        }

        public void setApiKey(String apiKey) {
            this.apiKey = apiKey;
        }

        public String getPublicKey() {
            return publicKey;
        }

        public void setPublicKey(String publicKey) {
            this.publicKey = publicKey;
        }

        public String getWebhookSecret() {
            return webhookSecret;
        }

        public void setWebhookSecret(String webhookSecret) {
            this.webhookSecret = webhookSecret;
        }

        public String getPublicBaseUrl() {
            return publicBaseUrl;
        }

        public void setPublicBaseUrl(String publicBaseUrl) {
            this.publicBaseUrl = publicBaseUrl;
        }

        public boolean useSimulation() {
            if (!enabled) {
                return false;
            }
            if (simulate) {
                return true;
            }
            return apiKey == null || apiKey.isBlank();
        }

        public boolean hasApiKey() {
            return apiKey != null && !apiKey.isBlank();
        }

        public boolean isConfigured() {
            return enabled && (useSimulation() || hasApiKey());
        }

        public String apiBaseUrl() {
            return sandbox ? "https://sandbox-api.fedapay.com/v1" : "https://api.fedapay.com/v1";
        }
    }
}
