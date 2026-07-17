package com.payflex.backend.config;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ReadListener;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Anti brute-force pragmatique pour les endpoints sensibles (login admin, login mobile,
 * vérification de code PIN, initialisation de paiement PayDunya) : compteur à fenêtre glissante
 * simple (reset périodique), clé = adresse IP + identifiant métier (nom d'utilisateur admin,
 * identifiant/téléphone mobile ou userId selon l'endpoint), stocké en mémoire locale au process
 * via {@link ConcurrentHashMap}.
 *
 * <p><b>⚠️ Limite connue / TODO scaling</b> — ce compteur est purement local à l'instance JVM
 * (pas de Redis pour l'instant, cohérent avec le déploiement actuel PayFlex en une seule
 * instance). Dès que le backend sera déployé en plusieurs instances (scaling horizontal /
 * load balancer), chaque instance aura son propre compteur indépendant : la protection restera
 * correcte par instance mais le seuil global réel pourra être dépassé par un attaquant réparti
 * sur plusieurs instances. Migration recommandée à ce moment-là : remplacer le
 * {@link ConcurrentHashMap} ci-dessous par un backend partagé (Redis — ex. bucket4j-redis,
 * Lettuce + scripts Lua, ou équivalent).</p>
 */
public class RateLimitFilter extends OncePerRequestFilter {

    private static final String TOO_MANY_ATTEMPTS_MESSAGE =
        "Trop de tentatives. Merci de réessayer dans quelques minutes.";

    private enum IdentifierSource { FORM_USERNAME, JSON_IDENTIFIER_OR_PHONE, JSON_USER_ID, JSON_CLIENT_USER_ID }

    private record RouteRule(String method, String path, int maxAttempts, long windowMillis, IdentifierSource identifierSource) {}

    private static final long FIVE_MIN_MS = 5 * 60_000L;

    private static final List<RouteRule> RULES = List.of(
        // Connexion admin (formulaire Spring Security /login) : 5 tentatives / 5 min par IP+identifiant.
        new RouteRule("POST", "/login", 5, FIVE_MIN_MS, IdentifierSource.FORM_USERNAME),
        // Connexion mobile (client ou agent) : même seuil.
        new RouteRule("POST", "/api/mobile/auth/login", 5, FIVE_MIN_MS, IdentifierSource.JSON_IDENTIFIER_OR_PHONE),
        // Vérification de code PIN client par un agent (brute-force PIN à 4 chiffres sinon trivial).
        new RouteRule("POST", "/api/mobile/agent/verify-client-pin", 5, FIVE_MIN_MS, IdentifierSource.JSON_CLIENT_USER_ID),
        // Création de cotisation : couvre aussi la saisie du PIN client par l'agent (collecte cash).
        new RouteRule("POST", "/api/mobile/contributions", 12, FIVE_MIN_MS, IdentifierSource.JSON_USER_ID),
        // Initialisation de paiement PayDunya (cotisation et adhésion) : seuil un peu plus large
        // (usage légitime répété possible : retry réseau) mais toujours borné.
        new RouteRule("POST", "/api/mobile/contributions/paydunya/init", 8, FIVE_MIN_MS, IdentifierSource.JSON_USER_ID),
        new RouteRule("POST", "/api/mobile/adhesion/paydunya/init", 8, FIVE_MIN_MS, IdentifierSource.JSON_USER_ID)
    );

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final ConcurrentHashMap<String, Counter> counters = new ConcurrentHashMap<>();

    private static final class Counter {
        final AtomicInteger count = new AtomicInteger(0);
        volatile long windowStartMillis;
        volatile long lastAccessMillis;

        Counter(long now) {
            this.windowStartMillis = now;
            this.lastAccessMillis = now;
        }
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
        throws ServletException, IOException {
        RouteRule rule = matchRule(request);
        if (rule == null) {
            filterChain.doFilter(request, response);
            return;
        }
        HttpServletRequest effectiveRequest = request;
        String identifier;
        if (rule.identifierSource() == IdentifierSource.FORM_USERNAME) {
            identifier = safe(request.getParameter("username"));
        } else {
            CachedBodyHttpServletRequest cached = new CachedBodyHttpServletRequest(request);
            effectiveRequest = cached;
            identifier = extractJsonIdentifier(cached.getCachedBody(), rule.identifierSource());
        }
        String key = rule.method() + " " + rule.path() + "|" + clientIp(request) + "|" + identifier;
        if (tryConsume(key, rule)) {
            filterChain.doFilter(effectiveRequest, response);
        } else {
            respondTooManyRequests(response);
        }
    }

    private boolean tryConsume(String key, RouteRule rule) {
        long now = System.currentTimeMillis();
        Counter counter = counters.computeIfAbsent(key, k -> new Counter(now));
        synchronized (counter) {
            if (now - counter.windowStartMillis > rule.windowMillis()) {
                counter.windowStartMillis = now;
                counter.count.set(0);
            }
            counter.lastAccessMillis = now;
            int attempts = counter.count.incrementAndGet();
            return attempts <= rule.maxAttempts();
        }
    }

    private static void respondTooManyRequests(HttpServletResponse response) throws IOException {
        response.setStatus(429);
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write("{\"message\":\"" + TOO_MANY_ATTEMPTS_MESSAGE + "\"}");
    }

    private static RouteRule matchRule(HttpServletRequest request) {
        String method = request.getMethod();
        String path = request.getRequestURI();
        String ctx = request.getContextPath();
        if (ctx != null && !ctx.isBlank() && path.startsWith(ctx)) {
            path = path.substring(ctx.length());
        }
        for (RouteRule r : RULES) {
            if (r.method().equalsIgnoreCase(method) && r.path().equals(path)) {
                return r;
            }
        }
        return null;
    }

    private String extractJsonIdentifier(byte[] body, IdentifierSource source) {
        if (body == null || body.length == 0) {
            return "";
        }
        try {
            JsonNode node = objectMapper.readTree(body);
            return switch (source) {
                case JSON_IDENTIFIER_OR_PHONE -> {
                    String id = textOrEmpty(node, "identifier");
                    yield id.isEmpty() ? textOrEmpty(node, "phone") : id;
                }
                case JSON_USER_ID -> textOrEmpty(node, "userId");
                case JSON_CLIENT_USER_ID -> textOrEmpty(node, "clientUserId");
                default -> "";
            };
        } catch (Exception ex) {
            return "";
        }
    }

    private static String textOrEmpty(JsonNode node, String field) {
        if (node == null) {
            return "";
        }
        JsonNode v = node.get(field);
        return v == null || v.isNull() ? "" : v.asText("");
    }

    private static String safe(String v) {
        return v == null ? "" : v.trim();
    }

    private static String clientIp(HttpServletRequest request) {
        String xff = request.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) {
            return xff.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }

    /** Purge périodique des compteurs inactifs (évite une fuite mémoire à long terme). */
    @Scheduled(fixedRate = 15 * 60_000L)
    public void cleanup() {
        long now = System.currentTimeMillis();
        counters.entrySet().removeIf(e -> now - e.getValue().lastAccessMillis > 30 * 60_000L);
    }

    /** Requête HTTP dont le corps est mis en cache en mémoire pour permettre une double lecture (filtre puis contrôleur). */
    private static final class CachedBodyHttpServletRequest extends HttpServletRequestWrapper {
        private final byte[] cachedBody;

        CachedBodyHttpServletRequest(HttpServletRequest request) throws IOException {
            super(request);
            this.cachedBody = request.getInputStream().readAllBytes();
        }

        byte[] getCachedBody() {
            return cachedBody;
        }

        @Override
        public ServletInputStream getInputStream() {
            ByteArrayInputStream byteArrayInputStream = new ByteArrayInputStream(cachedBody);
            return new ServletInputStream() {
                @Override
                public boolean isFinished() {
                    return byteArrayInputStream.available() == 0;
                }

                @Override
                public boolean isReady() {
                    return true;
                }

                @Override
                public void setReadListener(ReadListener readListener) {
                    // Lecture bloquante simple : pas de callback asynchrone nécessaire ici.
                }

                @Override
                public int read() {
                    return byteArrayInputStream.read();
                }
            };
        }

        @Override
        public BufferedReader getReader() throws IOException {
            return new BufferedReader(new InputStreamReader(getInputStream(), StandardCharsets.UTF_8));
        }
    }
}
