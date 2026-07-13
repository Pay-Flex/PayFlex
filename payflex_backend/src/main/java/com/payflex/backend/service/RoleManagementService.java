package com.payflex.backend.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.text.Normalizer;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

@Service
public class RoleManagementService {

    private static final int ROLE_CODE_MAX_LEN = 40;

    private static final Set<String> PROTECTED_ROLE_CODES = Set.of("client", "agent");

    private final JdbcTemplate jdbcTemplate;

    public RoleManagementService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<RoleOption> listRoles() {
        return jdbcTemplate.query(
            "SELECT id, code, label, description, sort_order FROM roles ORDER BY sort_order, label",
            (rs, i) -> new RoleOption(
                rs.getLong("id"),
                rs.getString("code"),
                rs.getString("label"),
                rs.getString("description"),
                rs.getInt("sort_order")
            )
        );
    }

    public Optional<RoleOption> findRoleById(long id) {
        List<RoleOption> rows = jdbcTemplate.query(
            "SELECT id, code, label, description, sort_order FROM roles WHERE id = ?",
            (rs, i) -> new RoleOption(
                rs.getLong("id"),
                rs.getString("code"),
                rs.getString("label"),
                rs.getString("description"),
                rs.getInt("sort_order")
            ),
            id
        );
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    /** Nombre d'utilisateurs métier par rôle (agrégat brut). */
    public Map<Long, Long> userCountsByRole() {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
            "SELECT role_id, COUNT(*) AS c FROM users GROUP BY role_id"
        );
        Map<Long, Long> map = new HashMap<>();
        for (Map<String, Object> row : rows) {
            Object rid = row.get("role_id");
            Object c = row.get("c");
            if (rid instanceof Number && c instanceof Number) {
                map.put(((Number) rid).longValue(), ((Number) c).longValue());
            }
        }
        return map;
    }

    /** Compteur par id de rôle, 0 si aucun utilisateur. */
    public Map<Long, Long> userCountsForRoles(List<RoleOption> roles) {
        Map<Long, Long> raw = userCountsByRole();
        Map<Long, Long> out = new LinkedHashMap<>();
        for (RoleOption r : roles) {
            out.put(r.id(), raw.getOrDefault(r.id(), 0L));
        }
        return out;
    }

    public long countUsersForRole(long roleId) {
        Long n = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM users WHERE role_id = ?",
            Long.class,
            roleId
        );
        return n == null ? 0L : n;
    }

    public boolean isProtectedRoleCode(String code) {
        return code != null && PROTECTED_ROLE_CODES.contains(code.toLowerCase(Locale.ROOT));
    }

    /**
     * Code technique : minuscules, chiffres et underscore ; utilisé en interne et pour les filtres.
     */
    public String normalizeRoleCode(String raw) {
        if (raw == null || raw.isBlank()) {
            throw new IllegalArgumentException("ROLE_CODE_REQUIRED");
        }
        String s = raw.trim().toLowerCase(Locale.ROOT).replace('-', '_').replaceAll("\\s+", "_");
        if (!s.matches("[a-z][a-z0-9_]{0,38}")) {
            throw new IllegalArgumentException("ROLE_CODE_INVALID");
        }
        return s;
    }

    /**
     * Crée un profil métier. Si {@code codeRaw} est vide, une référence technique unique est dérivée du nom affiché
     * (lettres sans accent, tout en minuscules, séparateurs en underscore), pour éviter de demander un « code » à l’administrateur.
     */
    public void createRole(String codeRaw, String label, String description) {
        requireText(label, "ROLE_LABEL_REQUIRED");
        String code = (codeRaw != null && !codeRaw.isBlank())
            ? normalizeRoleCode(codeRaw)
            : generateUniqueRoleCodeFromLabel(label.trim());
        Integer dup = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM roles WHERE code = ?",
            Integer.class,
            code
        );
        if (dup != null && dup > 0) {
            throw new IllegalArgumentException("ROLE_DUPLICATE");
        }
        int sortOrder = nextRoleSortOrder();
        jdbcTemplate.update(
            "INSERT INTO roles (code, label, description, sort_order) VALUES (?, ?, ?, ?)",
            code,
            label.trim(),
            blankToNull(description),
            sortOrder
        );
    }

    private String generateUniqueRoleCodeFromLabel(String label) {
        String base = truncateRoleCode(slugFromLabel(label));
        String candidate = base;
        for (int n = 2; n < 500; n++) {
            Integer cnt = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM roles WHERE code = ?",
                Integer.class,
                candidate
            );
            if (cnt == null || cnt == 0) {
                return candidate;
            }
            String suffix = "_" + n;
            int maxStem = ROLE_CODE_MAX_LEN - suffix.length();
            if (maxStem < 4) {
                maxStem = 4;
            }
            String stem = base.length() > maxStem ? base.substring(0, maxStem) : base;
            stem = stem.replaceAll("_+$", "");
            if (stem.isEmpty() || !Character.isLetter(stem.charAt(0))) {
                stem = "profil";
                stem = stem.length() > maxStem ? stem.substring(0, maxStem) : stem;
            }
            candidate = stem + suffix;
            if (candidate.length() > ROLE_CODE_MAX_LEN) {
                candidate = candidate.substring(0, ROLE_CODE_MAX_LEN);
            }
        }
        throw new IllegalArgumentException("ROLE_DUPLICATE");
    }

    /** À partir du libellé affiché : minuscules, sans accents, caractères spéciaux → underscore. */
    private static String slugFromLabel(String label) {
        String trimmed = label.trim();
        String asciiish = Normalizer.normalize(trimmed, Normalizer.Form.NFD)
            .replaceAll("\\p{M}+", "");
        String lower = asciiish.toLowerCase(Locale.ROOT);
        String unders = lower.replaceAll("[^a-z0-9]+", "_");
        unders = unders.replaceAll("_+", "_").replaceAll("^_|_$", "");
        if (unders.isEmpty()) {
            return "profil";
        }
        char first = unders.charAt(0);
        if (!Character.isLetter(first)) {
            unders = "profil_" + unders;
            unders = unders.replaceAll("_+", "_").replaceAll("^_|_$", "");
        }
        return unders.isEmpty() ? "profil" : unders;
    }

    private static String truncateRoleCode(String code) {
        if (code == null || code.isBlank()) {
            return "profil";
        }
        String t = code.length() <= ROLE_CODE_MAX_LEN ? code : code.substring(0, ROLE_CODE_MAX_LEN);
        t = t.replaceAll("_+$", "").replaceAll("^_", "");
        if (t.isEmpty()) {
            return "profil";
        }
        if (!Character.isLetter(t.charAt(0))) {
            t = "p_" + t;
            t = t.length() <= ROLE_CODE_MAX_LEN ? t : t.substring(0, ROLE_CODE_MAX_LEN);
            t = t.replaceAll("_+$", "");
        }
        return t.isEmpty() ? "profil" : t;
    }

    public void updateRole(long id, String label, String description) {
        if (id <= 0) {
            throw new IllegalArgumentException("ROLE_INVALID_ID");
        }
        findRoleById(id).orElseThrow(() -> new IllegalArgumentException("ROLE_NOT_FOUND"));
        requireText(label, "ROLE_LABEL_REQUIRED");
        jdbcTemplate.update(
            "UPDATE roles SET label = ?, description = ? WHERE id = ?",
            label.trim(),
            blankToNull(description),
            id
        );
    }

    private int nextRoleSortOrder() {
        Integer max = jdbcTemplate.queryForObject("SELECT COALESCE(MAX(sort_order), 0) FROM roles", Integer.class);
        int base = max == null ? 0 : max;
        return base + 10;
    }

    /**
     * Supprime un rôle personnalisé sans utilisateurs. Les rôles système client/agent sont refusés.
     */
    public void deleteRole(long id) {
        if (id <= 0) {
            throw new IllegalArgumentException("ROLE_INVALID_ID");
        }
        RoleOption existing = findRoleById(id).orElseThrow(() -> new IllegalArgumentException("ROLE_NOT_FOUND"));
        if (isProtectedRoleCode(existing.code())) {
            throw new IllegalArgumentException("ROLE_PROTECTED");
        }
        if (countUsersForRole(id) > 0) {
            throw new IllegalArgumentException("ROLE_IN_USE");
        }
        jdbcTemplate.update("DELETE FROM roles WHERE id = ?", id);
    }

    private static void requireText(String value, String errorCode) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(errorCode);
        }
    }

    private static String blankToNull(String s) {
        return (s == null || s.isBlank()) ? null : s.trim();
    }

    public List<PermissionOption> listPermissions() {
        return jdbcTemplate.query(
            "SELECT id, code, label, category, description FROM permissions ORDER BY category, label",
            (rs, i) -> new PermissionOption(
                rs.getLong("id"),
                rs.getString("code"),
                rs.getString("label"),
                rs.getString("category"),
                rs.getString("description")
            )
        );
    }

    /**
     * Pour l'écran admin : pour chaque couple (role, permission), indique si la permission est accordée.
     */
    public Map<Long, Map<Long, Boolean>> permissionMatrix() {
        List<RoleOption> roles = listRoles();
        List<PermissionOption> perms = listPermissions();
        Map<Long, Map<Long, Boolean>> matrix = new LinkedHashMap<>();
        for (RoleOption r : roles) {
            Map<Long, Boolean> row = new LinkedHashMap<>();
            for (PermissionOption p : perms) {
                row.put(p.id(), false);
            }
            matrix.put(r.id(), row);
        }
        List<java.util.Map<String, Object>> pairs = jdbcTemplate.queryForList(
            "SELECT role_id, permission_id FROM role_permissions"
        );
        for (java.util.Map<String, Object> row : pairs) {
            long rid = ((Number) row.get("role_id")).longValue();
            long pid = ((Number) row.get("permission_id")).longValue();
            Map<Long, Boolean> rrow = matrix.get(rid);
            if (rrow != null) {
                rrow.put(pid, true);
            }
        }
        return matrix;
    }

    public void setPermissionGranted(long roleId, long permissionId, boolean granted) {
        if (roleId <= 0 || permissionId <= 0) return;
        if (granted) {
            jdbcTemplate.update(
                "INSERT IGNORE INTO role_permissions (role_id, permission_id) VALUES (?, ?)",
                roleId,
                permissionId
            );
        } else {
            jdbcTemplate.update(
                "DELETE FROM role_permissions WHERE role_id = ? AND permission_id = ?",
                roleId,
                permissionId
            );
        }
    }

    public record RoleOption(long id, String code, String label, String description, int sortOrder) {}

    public record PermissionOption(long id, String code, String label, String category, String description) {}
}
