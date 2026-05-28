package com.payflex.backend.service;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Locale;

/**
 * Téléphone obligatoire et unique par compte ; e-mail optionnel et unique s'il est renseigné.
 */
@Service
public class UserContactUniquenessService {

    private final JdbcTemplate jdbcTemplate;

    public UserContactUniquenessService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void assertPhoneAvailable(String phoneRaw, Long excludeUserId) {
        String phone = phoneRaw == null ? "" : phoneRaw.trim();
        if (phone.isBlank()) {
            throw new IllegalArgumentException("Téléphone requis.");
        }
        String digits = normalizePhoneDigits(phone);
        String digitsCompare = digits.isEmpty() ? phone : digits;
        Long otherId = findOtherUserId(
            """
            SELECT u.id FROM users u
            WHERE (? IS NULL OR u.id <> ?)
              AND (
                TRIM(u.phone) = ?
                OR REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(u.phone), ' ', ''), '-', ''), '(', ''), ')', ''), '+', '') = ?
              )
            LIMIT 1
            """,
            excludeUserId,
            excludeUserId,
            phone,
            digitsCompare
        );
        if (otherId != null) {
            throw new IllegalArgumentException("Ce numéro de téléphone est déjà utilisé par un autre compte.");
        }
    }

    public void assertEmailAvailable(String emailRaw, Long excludeUserId) {
        String email = normalizeEmail(emailRaw);
        if (email == null) {
            return;
        }
        Long otherId = findOtherUserId(
            """
            SELECT u.id FROM users u
            WHERE LOWER(TRIM(u.email)) = ?
              AND (? IS NULL OR u.id <> ?)
            LIMIT 1
            """,
            email,
            excludeUserId,
            excludeUserId
        );
        if (otherId != null) {
            throw new IllegalArgumentException("Cet e-mail est déjà associé à un autre compte.");
        }
    }

    public static String normalizeEmail(String emailRaw) {
        if (emailRaw == null) {
            return null;
        }
        String trimmed = emailRaw.trim();
        if (trimmed.isEmpty()) {
            return null;
        }
        return trimmed.toLowerCase(Locale.ROOT);
    }

    public static void rethrowContactConflict(DataIntegrityViolationException ex) {
        String msg = ex.getMessage();
        if (msg != null) {
            String lower = msg.toLowerCase(Locale.ROOT);
            if (lower.contains("uk_users_email") || lower.contains("users.email")) {
                throw new IllegalArgumentException("Cet e-mail est déjà associé à un autre compte.");
            }
            if (lower.contains("phone") || lower.contains("uk_users")) {
                throw new IllegalArgumentException("Ce numéro de téléphone est déjà utilisé par un autre compte.");
            }
        }
        throw ex;
    }

    private Long findOtherUserId(String sql, Object... args) {
        List<Long> ids = jdbcTemplate.query(sql, (rs, rowNum) -> rs.getLong(1), args);
        return ids.isEmpty() ? null : ids.get(0);
    }

    private static String normalizePhoneDigits(String phone) {
        if (phone == null) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < phone.length(); i++) {
            char c = phone.charAt(i);
            if (c >= '0' && c <= '9') {
                sb.append(c);
            }
        }
        return sb.toString();
    }
}
