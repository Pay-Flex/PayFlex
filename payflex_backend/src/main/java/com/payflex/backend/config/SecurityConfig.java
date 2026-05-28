package com.payflex.backend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.WebSecurityCustomizer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.JdbcUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;

import javax.sql.DataSource;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /**
     * API mobile + webhooks : hors filtre de sécurité admin (évite les 302 sur POST JSON).
     * Spring Boot 3 utilise des {@code MvcRequestMatcher} qui ne couvrent pas toujours les POST API.
     */
    @Bean
    WebSecurityCustomizer mobileApiSecurityBypass() {
        return web -> web.ignoring().requestMatchers("/api/mobile/**", "/api/fedapay/**");
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers(
                    "/login",
                    "/css/**",
                    "/js/**",
                    "/img/**",
                    "/actuator/health",
                    "/uploads/**"
                ).permitAll()
                .requestMatchers("/admin", "/admin/**").hasAnyRole("ADMIN", "GESTIONNAIRE")
                .requestMatchers("/").hasAnyRole("ADMIN", "GESTIONNAIRE")
                .anyRequest().authenticated()
            )
            .exceptionHandling(ex -> ex.accessDeniedHandler((request, response, accessDeniedException) -> {
                String ctx = request.getContextPath();
                response.sendRedirect(ctx + "/admin?forbidden=1");
            }))
            .formLogin(form -> form
                .loginPage("/login")
                .defaultSuccessUrl("/admin", true)
                .permitAll()
            )
            .logout(logout -> logout
                .logoutUrl("/logout")
                .logoutSuccessUrl("/login?logout")
            )
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED)
                .maximumSessions(1)
                .maxSessionsPreventsLogin(false)
            );
        return http.build();
    }

    @Bean
    public UserDetailsService users(DataSource dataSource) {
        JdbcUserDetailsManager manager = new JdbcUserDetailsManager(dataSource);
        manager.setUsersByUsernameQuery("""
            SELECT username, password, enabled
            FROM admin_users
            WHERE username = ?
            """);
        manager.setAuthoritiesByUsernameQuery("""
            SELECT username, authority
            FROM admin_authorities
            WHERE username = ?
            """);
        return manager;
    }

    @Bean
    public JdbcTemplate jdbcTemplate(DataSource dataSource) {
        return new JdbcTemplate(dataSource);
    }
}
