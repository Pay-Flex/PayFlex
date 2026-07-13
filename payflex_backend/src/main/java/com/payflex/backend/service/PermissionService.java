package com.payflex.backend.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class PermissionService {

    public static final String MOBILE_CATALOG_VIEW = "MOBILE_CATALOG_VIEW";
    public static final String MOBILE_CONTRIBUTION_CREATE = "MOBILE_CONTRIBUTION_CREATE";
    public static final String MOBILE_CONTRIBUTION_VALIDATE = "MOBILE_CONTRIBUTION_VALIDATE";
    public static final String MOBILE_REGISTRATION_AGENT = "MOBILE_REGISTRATION_AGENT";

    private final JdbcTemplate jdbcTemplate;

    public PermissionService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public boolean userHasPermission(long userId, String permissionCode) {
        if (userId <= 0 || permissionCode == null || permissionCode.isBlank()) return false;
        Long n = jdbcTemplate.queryForObject(
            """
            SELECT COUNT(*)
            FROM users u
            JOIN role_permissions rp ON rp.role_id = u.role_id
            JOIN permissions p ON p.id = rp.permission_id
            WHERE u.id = ? AND p.code = ?
            """,
            Long.class,
            userId,
            permissionCode
        );
        return n != null && n > 0;
    }

    public List<String> permissionCodesForUser(long userId) {
        if (userId <= 0) return List.of();
        return jdbcTemplate.query(
            """
            SELECT p.code
            FROM users u
            JOIN role_permissions rp ON rp.role_id = u.role_id
            JOIN permissions p ON p.id = rp.permission_id
            WHERE u.id = ?
            ORDER BY p.code
            """,
            (rs, i) -> rs.getString(1),
            userId
        );
    }

}
