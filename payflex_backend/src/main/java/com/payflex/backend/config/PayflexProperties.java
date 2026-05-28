package com.payflex.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "payflex")
public class PayflexProperties {

    private Contributions contributions = new Contributions();
    private Fedapay fedapay = new Fedapay();

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

        public boolean isConfigured() {
            return enabled && apiKey != null && !apiKey.isBlank();
        }

        public String apiBaseUrl() {
            return sandbox ? "https://sandbox-api.fedapay.com/v1" : "https://api.fedapay.com/v1";
        }
    }
}
