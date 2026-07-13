package com.payflex.backend.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpServletResponseWrapper;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.boot.web.servlet.ServletContextInitializer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.net.URI;

/**
 * Secours derrière tunnel HTTPS (LocalTunnel, Cloudflare, etc.) : si {@code PAYFLEX_PUBLIC_URL} est en
 * {@code https://}, force schéma HTTPS + cookies de session {@code Secure} lorsque la requête
 * arrive sur le hostname public mais sans {@code X-Forwarded-Proto} (redirections admin en
 * {@code http://} → boucle ou page inaccessible).
 * <p>
 * Complète {@code server.forward-headers-strategy: framework} (déjà requis).
 */
@Configuration
public class PublicUrlHttpsConfig {

    @Bean
    ServletContextInitializer publicUrlSecureSessionCookies(PayflexProperties payflexProperties) {
        return servletContext -> {
            if (isHttpsPublicUrl(payflexProperties)) {
                var cookieConfig = servletContext.getSessionCookieConfig();
                cookieConfig.setSecure(true);
                cookieConfig.setHttpOnly(true);
            }
        };
    }

    @Bean
    FilterRegistrationBean<OncePerRequestFilter> publicUrlHttpsRequestFilter(PayflexProperties payflexProperties) {
        String publicHost = resolvePublicHost(payflexProperties);
        boolean active = publicHost != null;
        OncePerRequestFilter filter = new OncePerRequestFilter() {
            @Override
            protected void doFilterInternal(
                HttpServletRequest request,
                HttpServletResponse response,
                FilterChain filterChain
            ) throws ServletException, IOException {
                if (!active || !matchesPublicHost(request, publicHost)) {
                    filterChain.doFilter(request, response);
                    return;
                }
                HttpServletRequest wrappedRequest = new HttpsRequestWrapper(request);
                HttpServletResponse wrappedResponse = new HttpsLocationResponseWrapper(response, publicHost);
                filterChain.doFilter(wrappedRequest, wrappedResponse);
            }
        };
        FilterRegistrationBean<OncePerRequestFilter> registration = new FilterRegistrationBean<>(filter);
        registration.setOrder(Ordered.HIGHEST_PRECEDENCE + 10);
        return registration;
    }

    private static boolean isHttpsPublicUrl(PayflexProperties payflexProperties) {
        String base = payflexProperties.getFedapay().getPublicBaseUrl();
        return base != null && base.regionMatches(true, 0, "https://", 0, 8);
    }

    private static boolean matchesPublicHost(HttpServletRequest request, String publicHost) {
        if (publicHost.equalsIgnoreCase(request.getServerName())) {
            return true;
        }
        String hostHeader = request.getHeader("Host");
        if (hostHeader == null || hostHeader.isBlank()) {
            return false;
        }
        int colon = hostHeader.indexOf(':');
        String host = (colon >= 0 ? hostHeader.substring(0, colon) : hostHeader).trim();
        return publicHost.equalsIgnoreCase(host);
    }

    private static String resolvePublicHost(PayflexProperties payflexProperties) {
        if (!isHttpsPublicUrl(payflexProperties)) {
            return null;
        }
        try {
            String host = URI.create(payflexProperties.getFedapay().getPublicBaseUrl().trim()).getHost();
            return host == null || host.isBlank() ? null : host.toLowerCase();
        } catch (IllegalArgumentException ex) {
            return null;
        }
    }

    private static String toHttpsIfPublicHost(String location, String publicHost) {
        if (location == null || publicHost == null) {
            return location;
        }
        if (!location.regionMatches(true, 0, "http://", 0, 7)) {
            return location;
        }
        String remainder = location.substring(7);
        int slash = remainder.indexOf('/');
        String hostPart = slash >= 0 ? remainder.substring(0, slash) : remainder;
        int colon = hostPart.indexOf(':');
        String host = colon >= 0 ? hostPart.substring(0, colon) : hostPart;
        if (!publicHost.equalsIgnoreCase(host)) {
            return location;
        }
        return "https://" + remainder;
    }

    private static final class HttpsRequestWrapper extends HttpServletRequestWrapper {

        HttpsRequestWrapper(HttpServletRequest request) {
            super(request);
        }

        @Override
        public boolean isSecure() {
            return true;
        }

        @Override
        public String getScheme() {
            return "https";
        }

        @Override
        public int getServerPort() {
            int port = super.getServerPort();
            if (port == 80 || port == 8088) {
                return 443;
            }
            return port;
        }
    }

    private static final class HttpsLocationResponseWrapper extends HttpServletResponseWrapper {

        private final String publicHost;

        HttpsLocationResponseWrapper(HttpServletResponse response, String publicHost) {
            super(response);
            this.publicHost = publicHost;
        }

        @Override
        public void sendRedirect(String location) throws IOException {
            super.sendRedirect(rewriteLocation(location, publicHost));
        }

        @Override
        public void setHeader(String name, String value) {
            if ("Location".equalsIgnoreCase(name)) {
                value = rewriteLocation(value, publicHost);
            }
            super.setHeader(name, value);
        }

        @Override
        public void addHeader(String name, String value) {
            if ("Location".equalsIgnoreCase(name)) {
                value = rewriteLocation(value, publicHost);
            }
            super.addHeader(name, value);
        }
    }

    private static String rewriteLocation(String location, String publicHost) {
        if (location == null || publicHost == null) {
            return location;
        }
        if (location.startsWith("/")) {
            return "https://" + publicHost + location;
        }
        return toHttpsIfPublicHost(location, publicHost);
    }
}
