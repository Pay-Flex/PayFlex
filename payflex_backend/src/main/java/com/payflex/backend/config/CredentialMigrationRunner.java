package com.payflex.backend.config;

import com.payflex.backend.service.CredentialHashService;
import com.payflex.backend.service.CredentialVaultService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;

/**
 * Migration unique au démarrage : texte clair / {noop} → BCrypt.
 */
@Component
public class CredentialMigrationRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(CredentialMigrationRunner.class);

    private final JdbcTemplate jdbcTemplate;
    private final CredentialHashService credentialHashService;
    private final CredentialVaultService credentialVaultService;

    public CredentialMigrationRunner(
        JdbcTemplate jdbcTemplate,
        CredentialHashService credentialHashService,
        CredentialVaultService credentialVaultService
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.credentialHashService = credentialHashService;
        this.credentialVaultService = credentialVaultService;
    }

    @Override
    public void run(ApplicationArguments args) {
        migrateMobileUsers();
        migrateRegistrationRequests();
        migrateAdminUsers();
        int backfilled = credentialVaultService.backfillUserVaultFromRegistrations();
        if (backfilled > 0) {
            log.info("Archive identifiants : {} compte(s) client synchronisé(s) depuis l'inscription.", backfilled);
        }
    }

    private void migrateMobileUsers() {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
            "SELECT id, pin, secret_code FROM users WHERE pin IS NOT NULL AND TRIM(pin) <> ''"
        );
        int updated = 0;
        for (Map<String, Object> row : rows) {
            long id = ((Number) row.get("id")).longValue();
            String pin = String.valueOf(row.get("pin"));
            if (credentialHashService.isBcryptHash(pin)) {
                continue;
            }
            String plain = pin.trim();
            if (plain.isEmpty()) {
                continue;
            }
            try {
                credentialVaultService.storeForUser(id, plain, null);
                String hashed = credentialHashService.hashMobilePin(plain);
                jdbcTemplate.update(
                    "UPDATE users SET pin = ?, secret_code = ? WHERE id = ?",
                    hashed,
                    hashed,
                    id
                );
                updated++;
            } catch (IllegalArgumentException ex) {
                credentialVaultService.storeForUser(id, plain, null);
                String hashed = credentialHashService.hashAdminPassword(plain);
                jdbcTemplate.update(
                    "UPDATE users SET pin = ?, secret_code = ? WHERE id = ?",
                    hashed,
                    hashed,
                    id
                );
                updated++;
            }
        }
        if (updated > 0) {
            log.info("Migration PIN mobile : {} compte(s) hashé(s).", updated);
        }
    }

    private void migrateRegistrationRequests() {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
            "SELECT id, pin, secret_code FROM registration_requests WHERE pin IS NOT NULL AND TRIM(pin) <> ''"
        );
        int updated = 0;
        for (Map<String, Object> row : rows) {
            long id = ((Number) row.get("id")).longValue();
            String pin = String.valueOf(row.get("pin"));
            if (credentialHashService.isBcryptHash(pin)) {
                continue;
            }
            String plain = pin.trim();
            if (plain.isEmpty()) {
                continue;
            }
            String hashed;
            try {
                hashed = credentialHashService.hashMobilePin(plain);
            } catch (IllegalArgumentException ex) {
                hashed = credentialHashService.hashAdminPassword(plain);
            }
            jdbcTemplate.update(
                "UPDATE registration_requests SET pin = ?, secret_code = ? WHERE id = ?",
                hashed,
                hashed,
                id
            );
            updated++;
        }
        if (updated > 0) {
            log.info("Migration demandes inscription : {} ligne(s) hashée(s).", updated);
        }
    }

    private void migrateAdminUsers() {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
            "SELECT username, password FROM admin_users"
        );
        int updated = 0;
        for (Map<String, Object> row : rows) {
            String username = String.valueOf(row.get("username"));
            String stored = String.valueOf(row.get("password"));
            if (credentialHashService.isBcryptHash(stored)) {
                continue;
            }
            String plain = credentialHashService.extractNoopPassword(stored);
            if (plain == null || plain.isBlank()) {
                continue;
            }
            String hashed = credentialHashService.hashAdminPassword(plain);
            jdbcTemplate.update(
                "UPDATE admin_users SET password = ? WHERE username = ?",
                hashed,
                username
            );
            updated++;
        }
        if (updated > 0) {
            log.info("Migration mots de passe admin : {} compte(s) hashé(s).", updated);
        }
    }
}
