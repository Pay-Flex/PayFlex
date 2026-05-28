package com.payflex.backend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class AdminCrudService {

    private static final Logger log = LoggerFactory.getLogger(AdminCrudService.class);

    private final JdbcTemplate jdbcTemplate;
    private final CredentialHashService credentialHashService;
    private final UserContactUniquenessService contactUniqueness;

    public AdminCrudService(
        JdbcTemplate jdbcTemplate,
        CredentialHashService credentialHashService,
        UserContactUniquenessService contactUniqueness
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.credentialHashService = credentialHashService;
        this.contactUniqueness = contactUniqueness;
    }

    private static final String USER_ROW_SELECT = """
        SELECT u.id, u.full_name, u.phone, u.role_id, r.code AS role, r.label AS role_label,
               u.city, u.profession, u.status, a.id AS agent_record_id
        FROM users u
        JOIN roles r ON r.id = u.role_id
        LEFT JOIN agents a ON a.user_id = u.id
        """;

    /**
     * Somme des prix catalogue pour chaque couple (client, produit) distinct : cotisation passée par l’agent
     * ou client rattaché à l’agent ({@code assigned_agent_user_id}).
     * Placeholder {@code %1$s} = alias SQL de {@code agents} (ex. {@code a}, {@code ag}).
     */
    private static final String SQL_AGENT_AUTO_OBJECTIVE_TMPL = """
            COALESCE((
              SELECT SUM(sub.row_price)
              FROM (
                SELECT DISTINCT con.user_id, con.product_id, pr.price AS row_price
                FROM contributions con
                INNER JOIN users cu ON cu.id = con.user_id AND cu.role_id = (SELECT id FROM roles WHERE code = 'client' LIMIT 1)
                INNER JOIN products pr ON pr.id = con.product_id
                WHERE con.product_id IS NOT NULL
                  AND (con.agent_id = %1$s.id OR cu.assigned_agent_user_id = %1$s.user_id)
              ) sub
            ), 0)
            """;

    /** Fragment SQL pour l’objectif terrain ; alias habituel {@code a} (voir aussi surcharge). */
    public static String terrainObjectiveSqlFragment() {
        return terrainObjectiveSqlFragment("a");
    }

    /** Même calcul avec l’alias réel de la table {@code agents} dans la requête parente. */
    public static String terrainObjectiveSqlFragment(String agentsTableAlias) {
        return SQL_AGENT_AUTO_OBJECTIVE_TMPL.trim().formatted(agentsTableAlias);
    }

    private UserRow mapUserRow(java.sql.ResultSet rs, int rowNum) throws java.sql.SQLException {
        Long agentRec = rs.getObject("agent_record_id", Long.class);
        return new UserRow(
            rs.getLong("id"),
            rs.getString("full_name"),
            rs.getString("phone"),
            rs.getLong("role_id"),
            rs.getString("role"),
            rs.getString("role_label"),
            rs.getString("city"),
            rs.getString("profession"),
            rs.getString("status"),
            agentRec
        );
    }

    public Optional<UserRow> findUserById(long id) {
        if (id <= 0) {
            return Optional.empty();
        }
        List<UserRow> rows = jdbcTemplate.query(
            USER_ROW_SELECT + " WHERE u.id = ?",
            this::mapUserRow,
            id
        );
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public List<UserRow> getUsers() {
        return jdbcTemplate.query(
            USER_ROW_SELECT + " ORDER BY u.created_at DESC",
            this::mapUserRow
        );
    }

    public PageResult<UserRow> getUsersPage(String q, String role, String status, int page, int size) {
        size = normalizePageSize(size);
        StringBuilder where = new StringBuilder(" WHERE 1=1 ");
        List<Object> args = new ArrayList<>();
        if (q != null && !q.isBlank()) {
            where.append(" AND (u.full_name LIKE ? OR u.phone LIKE ? OR u.city LIKE ?) ");
            String like = "%" + q.trim() + "%";
            args.add(like); args.add(like); args.add(like);
        }
        if (role != null && !role.isBlank()) {
            where.append(" AND r.code = ? ");
            args.add(role);
        }
        if (status != null && !status.isBlank()) {
            where.append(" AND u.status = ? ");
            args.add(status);
        }

        long total = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM users u JOIN roles r ON r.id = u.role_id " + where,
            args.toArray(),
            Long.class
        );
        List<Object> pageArgs = new ArrayList<>(args);
        pageArgs.add(size);
        pageArgs.add(page * size);

        List<UserRow> items = jdbcTemplate.query(
            USER_ROW_SELECT + where + " ORDER BY u.created_at DESC LIMIT ? OFFSET ?",
            pageArgs.toArray(),
            this::mapUserRow
        );
        return PageResult.of(items, page, size, total);
    }

    public void createUser(String fullName, String phone, long roleId, String city, String profession, String status) {
        createUser(fullName, phone, null, roleId, city, profession, status);
    }

    public void createUser(
        String fullName,
        String phone,
        String email,
        long roleId,
        String city,
        String profession,
        String status
    ) {
        requireText(fullName, "Nom complet requis");
        requireText(phone, "Téléphone requis");
        if (roleId <= 0) throw new IllegalArgumentException("Rôle invalide");
        contactUniqueness.assertPhoneAvailable(phone, null);
        String normalizedEmail = UserContactUniquenessService.normalizeEmail(email);
        contactUniqueness.assertEmailAvailable(normalizedEmail, null);
        try {
            jdbcTemplate.update(
                "INSERT INTO users (full_name, phone, email, role_id, city, profession, status) VALUES (?, ?, ?, ?, ?, ?, ?)",
                fullName,
                phone,
                normalizedEmail,
                roleId,
                city,
                profession,
                status
            );
        } catch (org.springframework.dao.DataIntegrityViolationException ex) {
            UserContactUniquenessService.rethrowContactConflict(ex);
        }
    }

    /**
     * Création d’un client mobile avec identifiants et dossier professionnel optionnel.
     */
    @Transactional(rollbackFor = Exception.class)
    public long createClientUser(
        String fullName,
        String phone,
        String email,
        long roleId,
        String city,
        String profession,
        String gender,
        String status,
        String mobilePin,
        String accountPassword,
        Long assignedAgentUserId,
        String workplaceName,
        String workplaceAddress,
        String bossName,
        String bossPhone
    ) {
        requireText(fullName, "Nom complet requis");
        requireText(phone, "Téléphone requis");
        if (roleId <= 0) {
            throw new IllegalArgumentException("Rôle invalide");
        }
        String roleCode = jdbcTemplate.queryForObject(
            "SELECT code FROM roles WHERE id = ?",
            String.class,
            roleId
        );
        if (roleCode == null || !"client".equals(roleCode)) {
            throw new IllegalArgumentException("Le profil sélectionné n’est pas un client.");
        }
        String st = normalizeUserStatus(status);
        String plainPin = mobilePin == null ? "" : mobilePin.trim();
        String plainPassword = accountPassword == null ? "" : accountPassword.trim();
        if (plainPin.isEmpty()) {
            throw new IllegalArgumentException("Code PIN mobile requis (4 à 12 chiffres).");
        }
        credentialHashService.validateMobilePin(plainPin);
        String hashedPin = credentialHashService.hashMobilePin(plainPin);
        String hashedPassword = plainPassword.isEmpty()
            ? hashedPin
            : credentialHashService.hashMobileCredential(plainPassword);

        contactUniqueness.assertPhoneAvailable(phone, null);
        String normalizedEmail = UserContactUniquenessService.normalizeEmail(email);
        contactUniqueness.assertEmailAvailable(normalizedEmail, null);
        if (assignedAgentUserId != null && assignedAgentUserId > 0) {
            Long agentOk = jdbcTemplate.queryForObject(
                """
                SELECT COUNT(*) FROM users u
                JOIN roles r ON r.id = u.role_id
                WHERE u.id = ? AND r.code = 'agent' AND u.status = 'valide'
                """,
                Long.class,
                assignedAgentUserId
            );
            if (agentOk == null || agentOk == 0) {
                throw new IllegalArgumentException("Agent parrain invalide.");
            }
        }

        String phoneTrim = phone.trim();
        String uniqueCode = "CL-" + phoneTrim.replaceAll("\\D", "");
        if (uniqueCode.length() < 6) {
            uniqueCode = "CL-" + System.currentTimeMillis();
        }

        try {
            jdbcTemplate.update(
                """
                INSERT INTO users (
                  full_name, phone, email, role_id, city, profession, gender, status,
                  pin, secret_code, account_password, unique_code,
                  assigned_agent_user_id, workplace_name, workplace_address, boss_name, boss_phone
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                fullName.trim(),
                phoneTrim,
                normalizedEmail,
                roleId,
                emptyToNull(city),
                emptyToNull(profession),
                emptyToNull(gender),
                st,
                hashedPin,
                hashedPin,
                hashedPassword,
                uniqueCode,
                assignedAgentUserId != null && assignedAgentUserId > 0 ? assignedAgentUserId : null,
                emptyToNull(workplaceName),
                emptyToNull(workplaceAddress),
                emptyToNull(bossName),
                emptyToNull(bossPhone)
            );
        } catch (org.springframework.dao.DataIntegrityViolationException ex) {
            UserContactUniquenessService.rethrowContactConflict(ex);
        }
        Long userId = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        if (userId == null || userId <= 0) {
            throw new IllegalStateException("Création client impossible.");
        }
        return userId;
    }

    public void updateUserStatus(long id, String status) {
        if (id <= 0) throw new IllegalArgumentException("ID utilisateur invalide");
        jdbcTemplate.update("UPDATE users SET status = ? WHERE id = ?", status, id);
    }

    public void updateUser(long id, String fullName, String phone, long roleId, String city, String profession, String status) {
        updateUser(id, fullName, phone, null, roleId, city, profession, status);
    }

    public void updateUser(
        long id,
        String fullName,
        String phone,
        String email,
        long roleId,
        String city,
        String profession,
        String status
    ) {
        if (id <= 0) throw new IllegalArgumentException("ID utilisateur invalide");
        requireText(fullName, "Nom complet requis");
        requireText(phone, "Téléphone requis");
        if (roleId <= 0) throw new IllegalArgumentException("Rôle invalide");
        contactUniqueness.assertPhoneAvailable(phone, id);
        String normalizedEmail = UserContactUniquenessService.normalizeEmail(email);
        contactUniqueness.assertEmailAvailable(normalizedEmail, id);
        String st = normalizeUserStatus(status);
        try {
            jdbcTemplate.update(
                "UPDATE users SET full_name = ?, phone = ?, email = ?, role_id = ?, city = ?, profession = ?, status = ? WHERE id = ?",
                fullName,
                phone,
                normalizedEmail,
                roleId,
                city,
                profession,
                st,
                id
            );
        } catch (org.springframework.dao.DataIntegrityViolationException ex) {
            UserContactUniquenessService.rethrowContactConflict(ex);
        }
    }

    private static String normalizeUserStatus(String status) {
        if (status == null || status.isBlank()) {
            return "pending";
        }
        String s = status.trim().toLowerCase();
        return switch (s) {
            case "valide", "pending", "bloque" -> s;
            default -> "pending";
        };
    }

    /**
     * Supprime un utilisateur métier et les données qui bloquaient la suppression (cotisations où il est client,
     * fiche agent, liens dans les demandes d'inscription).
     */
    @Transactional
    public void deleteUser(long id) {
        if (id <= 0) throw new IllegalArgumentException("ID utilisateur invalide");

        jdbcTemplate.update(
            "UPDATE registration_requests SET submitted_by_agent_user_id = NULL WHERE submitted_by_agent_user_id = ?",
            id
        );
        jdbcTemplate.update(
            "UPDATE registration_requests SET assigned_agent_user_id = NULL WHERE assigned_agent_user_id = ?",
            id
        );
        jdbcTemplate.update(
            "UPDATE users SET assigned_agent_user_id = NULL WHERE assigned_agent_user_id = ?",
            id
        );
        jdbcTemplate.update(
            "UPDATE users SET adhesion_collected_by_user_id = NULL WHERE adhesion_collected_by_user_id = ?",
            id
        );
        jdbcTemplate.update("DELETE FROM support_chat_messages WHERE user_id = ?", id);
        jdbcTemplate.update(
            "UPDATE contributions SET validated_by_user_id = NULL WHERE validated_by_user_id = ?",
            id
        );
        jdbcTemplate.update(
            "DELETE FROM admin_deletion_requests WHERE entity_type = 'user' AND entity_id = ?",
            id
        );

        List<Long> agentIds = jdbcTemplate.query(
            "SELECT id FROM agents WHERE user_id = ?",
            (rs, rowNum) -> rs.getLong("id"),
            id
        );
        for (Long agentPk : agentIds) {
            jdbcTemplate.update("UPDATE contributions SET agent_id = NULL WHERE agent_id = ?", agentPk);
        }
        jdbcTemplate.update("DELETE FROM agents WHERE user_id = ?", id);

        jdbcTemplate.update("DELETE FROM contributions WHERE user_id = ?", id);

        int deleted = jdbcTemplate.update("DELETE FROM users WHERE id = ?", id);
        if (deleted == 0) {
            throw new IllegalArgumentException("Utilisateur introuvable");
        }
    }

    public List<ProductCategoryRow> listProductCategories() {
        return jdbcTemplate.query(
            """
            SELECT pc.id, pc.code, pc.label, pc.sort_order,
                   (SELECT COUNT(*) FROM products p WHERE p.category_id = pc.id) AS product_count
            FROM product_categories pc
            ORDER BY pc.sort_order ASC, pc.label ASC
            """,
            (rs, rowNum) -> new ProductCategoryRow(
                rs.getLong("id"),
                rs.getString("code"),
                rs.getString("label"),
                rs.getInt("sort_order"),
                rs.getLong("product_count")
            )
        );
    }

    private String requireCategoryLabel(long categoryId) {
        try {
            return jdbcTemplate.queryForObject(
                "SELECT label FROM product_categories WHERE id = ?",
                String.class,
                categoryId
            );
        } catch (org.springframework.dao.EmptyResultDataAccessException ex) {
            throw new IllegalArgumentException("Catégorie produit invalide");
        }
    }

    public List<ProductRow> getProducts() {
        return jdbcTemplate.query(
            """
            SELECT p.id, p.code, p.name, p.category_id, pc.label AS category, p.price, p.min_daily_contribution,
                   p.availability,
                   p.description, p.featured,
                   p.image_main_path, p.image_detail_1_path, p.image_detail_2_path, p.image_url
            FROM products p
            JOIN product_categories pc ON pc.id = p.category_id
            ORDER BY p.created_at DESC
            """,
            (rs, rowNum) -> mapProductRow(rs)
        );
    }

    public PageResult<ProductRow> getProductsPage(String q, Long categoryId, String availability, int page, int size) {
        size = normalizePageSize(size);
        StringBuilder where = new StringBuilder(" WHERE 1=1 ");
        List<Object> args = new ArrayList<>();
        if (q != null && !q.isBlank()) {
            where.append(" AND (p.name LIKE ? OR p.code LIKE ?) ");
            String like = "%" + q.trim() + "%";
            args.add(like); args.add(like);
        }
        if (categoryId != null && categoryId > 0) {
            where.append(" AND p.category_id = ? ");
            args.add(categoryId);
        }
        if (availability != null && !availability.isBlank()) {
            where.append(" AND p.availability = ? ");
            args.add(availability);
        }

        String fromClause = " FROM products p JOIN product_categories pc ON pc.id = p.category_id ";

        long total = jdbcTemplate.queryForObject("SELECT COUNT(*) " + fromClause + where, args.toArray(), Long.class);
        List<Object> pageArgs = new ArrayList<>(args);
        pageArgs.add(size);
        pageArgs.add(page * size);

        List<ProductRow> items = jdbcTemplate.query(
            """
            SELECT p.id, p.code, p.name, p.category_id, pc.label AS category, p.price, p.min_daily_contribution,
                   p.availability,
                   p.description, p.featured,
                   p.image_main_path, p.image_detail_1_path, p.image_detail_2_path, p.image_url
            """ + fromClause + where + " ORDER BY p.created_at DESC LIMIT ? OFFSET ?",
            pageArgs.toArray(),
            (rs, rowNum) -> mapProductRow(rs)
        );
        return PageResult.of(items, page, size, total);
    }

    private ProductRow mapProductRow(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new ProductRow(
            rs.getLong("id"),
            rs.getString("code"),
            rs.getString("name"),
            rs.getLong("category_id"),
            rs.getString("category"),
            rs.getDouble("price"),
            rs.getDouble("min_daily_contribution"),
            rs.getString("availability"),
            rs.getString("description"),
            rs.getBoolean("featured"),
            rs.getString("image_main_path"),
            rs.getString("image_detail_1_path"),
            rs.getString("image_detail_2_path"),
            rs.getString("image_url"),
            previewImageUrl(rs.getString("image_main_path"), rs.getString("image_url"))
        );
    }

    private Path ensureProductUploadRoot() throws IOException {
        Path root = Path.of("uploads", "products");
        Files.createDirectories(root);
        return root;
    }

    private String storeProductFile(MultipartFile file) throws IOException {
        if (file == null || file.isEmpty()) {
            return null;
        }
        String ext = "";
        String original = file.getOriginalFilename();
        if (original != null && original.contains(".")) {
            ext = original.substring(original.lastIndexOf('.'));
            if (ext.length() > 12) {
                ext = "";
            }
        }
        String name = "prd_" + LocalDate.now().format(DateTimeFormatter.BASIC_ISO_DATE) + "_" + UUID.randomUUID() + ext;
        Path target = ensureProductUploadRoot().resolve(name);
        Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);
        return target.toString().replace("\\", "/");
    }

    private static String previewImageUrl(String imageMainPath, String imageUrl) {
        if (imageMainPath != null && !imageMainPath.isBlank()) {
            String n = imageMainPath.trim().replace('\\', '/');
            return n.startsWith("/") ? n : "/" + n;
        }
        return imageUrl;
    }

    /**
     * Code catalogue unique (colonne {@code code}, max 40 car.), généré automatiquement à la création.
     */
    private String generateUniqueProductCode() {
        for (int attempt = 0; attempt < 8; attempt++) {
            String raw = "PF-" + System.currentTimeMillis() + "-" + UUID.randomUUID().toString().replace("-", "").substring(0, 6).toUpperCase();
            if (raw.length() > 40) {
                raw = raw.substring(0, 40);
            }
            Long n = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM products WHERE code = ?", Long.class, raw);
            if (n != null && n == 0) {
                return raw;
            }
        }
        throw new IllegalStateException("Impossible de générer un code produit unique.");
    }

    private static void validateMinDailyContribution(double minDaily, double price) {
        if (minDaily <= 0) {
            throw new IllegalArgumentException("La cotisation journalière minimale doit être strictement positive.");
        }
        if (minDaily > price) {
            throw new IllegalArgumentException("La cotisation minimale ne peut pas dépasser le prix catalogue du produit.");
        }
    }

    public void createProduct(
        String name,
        long categoryId,
        double price,
        double minDailyContribution,
        String availability,
        String description,
        MultipartFile imageMain,
        MultipartFile imageDetail1,
        MultipartFile imageDetail2,
        boolean featured
    ) throws IOException {
        requireText(name, "Nom produit requis");
        String categoryLabel = requireCategoryLabel(categoryId);
        if (price <= 0) throw new IllegalArgumentException("Prix invalide");
        validateMinDailyContribution(minDailyContribution, price);
        if (imageMain == null || imageMain.isEmpty()) {
            throw new IllegalArgumentException("Image principale obligatoire (fichier à téléverser).");
        }
        String code = generateUniqueProductCode();
        String mainPath = storeProductFile(imageMain);
        String d1 = storeProductFile(imageDetail1);
        String d2 = storeProductFile(imageDetail2);
        jdbcTemplate.update(
            """
            INSERT INTO products (
              code, name, category_id, category, price, min_daily_contribution, availability, description,
              image_url, image_main_path, image_detail_1_path, image_detail_2_path, featured
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?)
            """,
            code, name, categoryId, categoryLabel, price, minDailyContribution, availability, description,
            mainPath, d1, d2, featured
        );
    }

    public void updateProduct(
        long id,
        String name,
        long categoryId,
        double price,
        double minDailyContribution,
        String availability,
        String description,
        MultipartFile imageMain,
        MultipartFile imageDetail1,
        MultipartFile imageDetail2,
        boolean featured
    ) throws IOException {
        if (id <= 0) throw new IllegalArgumentException("ID produit invalide");
        requireText(name, "Nom produit requis");
        String categoryLabel = requireCategoryLabel(categoryId);
        if (price <= 0) throw new IllegalArgumentException("Prix invalide");
        validateMinDailyContribution(minDailyContribution, price);

        java.util.Map<String, Object> cur = jdbcTemplate.queryForMap(
            """
            SELECT image_main_path, image_detail_1_path, image_detail_2_path
            FROM products WHERE id = ?
            """,
            id
        );
        String mainPath = (String) cur.get("image_main_path");
        String path1 = (String) cur.get("image_detail_1_path");
        String path2 = (String) cur.get("image_detail_2_path");
        if (imageMain != null && !imageMain.isEmpty()) {
            mainPath = storeProductFile(imageMain);
        }
        if (imageDetail1 != null && !imageDetail1.isEmpty()) {
            path1 = storeProductFile(imageDetail1);
        }
        if (imageDetail2 != null && !imageDetail2.isEmpty()) {
            path2 = storeProductFile(imageDetail2);
        }

        jdbcTemplate.update(
            """
            UPDATE products SET name = ?, category_id = ?, category = ?, price = ?, min_daily_contribution = ?, availability = ?, description = ?,
              image_main_path = ?, image_detail_1_path = ?, image_detail_2_path = ?, featured = ?
            WHERE id = ?
            """,
            name, categoryId, categoryLabel, price, minDailyContribution, availability, description,
            mainPath, path1, path2, featured, id
        );
    }

    public void deleteProduct(long id) {
        if (id <= 0) throw new IllegalArgumentException("ID produit invalide");
        jdbcTemplate.update("DELETE FROM products WHERE id = ?", id);
    }

    public List<AgentCandidate> getAgentCandidates() {
        return jdbcTemplate.query(
            """
            SELECT id, full_name, city, promote_from_client FROM (
              SELECT u.id, u.full_name, u.city, FALSE AS promote_from_client
              FROM users u
              JOIN roles r ON r.id = u.role_id
              WHERE r.code = 'agent'
                AND u.id NOT IN (SELECT user_id FROM agents)
              UNION ALL
              SELECT u.id, u.full_name, u.city, TRUE AS promote_from_client
              FROM users u
              JOIN roles r ON r.id = u.role_id
              WHERE r.code = 'client'
                AND u.status = 'valide'
                AND u.id NOT IN (SELECT user_id FROM agents)
            ) t
            ORDER BY full_name
            """,
            (rs, rowNum) -> new AgentCandidate(
                rs.getLong("id"),
                rs.getString("full_name"),
                rs.getString("city"),
                rs.getBoolean("promote_from_client")
            )
        );
    }

    public List<AgentRow> getAgents() {
        try {
            return jdbcTemplate.query(
                """
                SELECT a.id, u.full_name, u.city, a.zone_id, COALESCE(z.name, a.zone) AS zone_display, a.active,
                """
                        + "(" + terrainObjectiveSqlFragment() + ") AS terrain_objective "
                        + """
                FROM agents a
                JOIN users u ON u.id = a.user_id
                LEFT JOIN zones z ON z.id = a.zone_id
                ORDER BY a.created_at DESC
                """,
                (rs, rowNum) -> new AgentRow(
                    rs.getLong("id"),
                    rs.getString("full_name"),
                    rs.getString("city"),
                    (Long) rs.getObject("zone_id"),
                    rs.getString("zone_display"),
                    rs.getBoolean("active"),
                    rs.getDouble("terrain_objective")
                )
            );
        } catch (DataAccessException ex) {
            log.warn("Liste agents: fallback sans objectif terrain (raison: {})", ex.getMessage());
            return jdbcTemplate.query(
                """
                SELECT a.id, u.full_name, u.city, a.zone_id, COALESCE(z.name, a.zone) AS zone_display, a.active, 0 AS terrain_objective
                FROM agents a
                JOIN users u ON u.id = a.user_id
                LEFT JOIN zones z ON z.id = a.zone_id
                ORDER BY a.created_at DESC
                """,
                (rs, rowNum) -> new AgentRow(
                    rs.getLong("id"),
                    rs.getString("full_name"),
                    rs.getString("city"),
                    (Long) rs.getObject("zone_id"),
                    rs.getString("zone_display"),
                    rs.getBoolean("active"),
                    rs.getDouble("terrain_objective")
                )
            );
        }
    }

    public PageResult<AgentRow> getAgentsPage(String q, String zone, Boolean active, int page, int size) {
        size = normalizePageSize(size);
        StringBuilder where = new StringBuilder(" WHERE 1=1 ");
        List<Object> args = new ArrayList<>();
        if (q != null && !q.isBlank()) {
            where.append(" AND (u.full_name LIKE ? OR u.city LIKE ?) ");
            String like = "%" + q.trim() + "%";
            args.add(like); args.add(like);
        }
        if (zone != null && !zone.isBlank()) {
            where.append(" AND COALESCE(z.name, a.zone) LIKE ? ");
            args.add("%" + zone.trim() + "%");
        }
        if (active != null) {
            where.append(" AND a.active = ? ");
            args.add(active);
        }

        long total = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM agents a JOIN users u ON u.id = a.user_id LEFT JOIN zones z ON z.id = a.zone_id " + where,
            args.toArray(),
            Long.class
        );
        List<Object> pageArgs = new ArrayList<>(args);
        pageArgs.add(size);
        pageArgs.add(page * size);

        String pageFrom = " FROM agents a JOIN users u ON u.id = a.user_id LEFT JOIN zones z ON z.id = a.zone_id ";
        List<AgentRow> items;
        try {
            items = jdbcTemplate.query(
                "SELECT a.id, u.full_name, u.city, a.zone_id, COALESCE(z.name, a.zone) AS zone_display, a.active, ("
                        + terrainObjectiveSqlFragment() + ") AS terrain_objective " + pageFrom + where + " ORDER BY a.created_at DESC LIMIT ? OFFSET ?",
                pageArgs.toArray(),
                (rs, rowNum) -> new AgentRow(
                    rs.getLong("id"),
                    rs.getString("full_name"),
                    rs.getString("city"),
                    (Long) rs.getObject("zone_id"),
                    rs.getString("zone_display"),
                    rs.getBoolean("active"),
                    rs.getDouble("terrain_objective")
                )
            );
        } catch (DataAccessException ex) {
            log.warn("Pagination agents: fallback sans objectif terrain (raison: {})", ex.getMessage());
            items = jdbcTemplate.query(
                "SELECT a.id, u.full_name, u.city, a.zone_id, COALESCE(z.name, a.zone) AS zone_display, a.active, 0 AS terrain_objective " + pageFrom + where + " ORDER BY a.created_at DESC LIMIT ? OFFSET ?",
                pageArgs.toArray(),
                (rs, rowNum) -> new AgentRow(
                    rs.getLong("id"),
                    rs.getString("full_name"),
                    rs.getString("city"),
                    (Long) rs.getObject("zone_id"),
                    rs.getString("zone_display"),
                    rs.getBoolean("active"),
                    rs.getDouble("terrain_objective")
                )
            );
        }
        return PageResult.of(items, page, size, total);
    }

    @Transactional(rollbackFor = Exception.class)
    public void createAgent(long userId, long zoneId) {
        if (userId <= 0) throw new IllegalArgumentException("Utilisateur agent invalide");
        if (zoneId <= 0) throw new IllegalArgumentException("Zone requise");
        String zoneName = requireZoneName(zoneId);
        Long dup = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM agents WHERE user_id = ?", Long.class, userId);
        if (dup != null && dup > 0) {
            throw new IllegalArgumentException("Cet utilisateur a déjà une fiche agent.");
        }
        String roleCode = jdbcTemplate.queryForObject(
            """
            SELECT r.code FROM users u JOIN roles r ON r.id = u.role_id WHERE u.id = ?
            """,
            String.class,
            userId
        );
        if (roleCode == null) {
            throw new IllegalArgumentException("Utilisateur introuvable.");
        }
        if ("client".equals(roleCode)) {
            String st = jdbcTemplate.queryForObject("SELECT status FROM users WHERE id = ?", String.class, userId);
            if (!"valide".equals(st)) {
                throw new IllegalArgumentException("Le compte client doit être « valide » pour devenir agent terrain.");
            }
            Long agentRoleId = jdbcTemplate.queryForObject("SELECT id FROM roles WHERE code = 'agent' LIMIT 1", Long.class);
            if (agentRoleId == null || agentRoleId <= 0) {
                throw new IllegalStateException("Rôle « agent » introuvable.");
            }
            jdbcTemplate.update("UPDATE users SET role_id = ? WHERE id = ?", agentRoleId, userId);
        } else if (!"agent".equals(roleCode)) {
            throw new IllegalArgumentException("Seuls un agent (sans fiche) ou un client validé peuvent recevoir une fiche terrain.");
        }

        jdbcTemplate.update(
            "INSERT INTO agents (user_id, zone, zone_id, active, collected_total) VALUES (?, ?, ?, TRUE, 0)",
            userId,
            zoneName,
            zoneId
        );
    }

    public void updateAgent(long id, Long zoneId, String zoneLabel, boolean active) {
        if (id <= 0) throw new IllegalArgumentException("ID agent invalide");
        if (zoneId != null && zoneId > 0) {
            String zoneName = requireZoneName(zoneId);
            jdbcTemplate.update(
                "UPDATE agents SET zone_id = ?, zone = ?, active = ? WHERE id = ?",
                zoneId,
                zoneName,
                active,
                id
            );
        } else {
            requireText(zoneLabel, "Zone requise");
            jdbcTemplate.update(
                "UPDATE agents SET zone_id = NULL, zone = ?, active = ? WHERE id = ?",
                zoneLabel,
                active,
                id
            );
        }
    }

    @Transactional
    public void deleteAgent(long id) {
        if (id <= 0) throw new IllegalArgumentException("ID agent invalide");
        jdbcTemplate.update("UPDATE contributions SET agent_id = NULL WHERE agent_id = ?", id);
        int deleted = jdbcTemplate.update("DELETE FROM agents WHERE id = ?", id);
        if (deleted == 0) {
            throw new IllegalArgumentException("Agent introuvable");
        }
    }

    public List<UserChoice> getUserChoices() {
        return jdbcTemplate.query(
            "SELECT id, full_name FROM users ORDER BY full_name",
            (rs, rowNum) -> new UserChoice(rs.getLong("id"), rs.getString("full_name"))
        );
    }

    public List<ProductChoice> getProductChoices() {
        return jdbcTemplate.query(
            "SELECT id, name FROM products ORDER BY name",
            (rs, rowNum) -> new ProductChoice(rs.getLong("id"), rs.getString("name"))
        );
    }

    public List<AgentChoice> getAgentChoices() {
        return jdbcTemplate.query(
            """
            SELECT a.id, u.full_name
            FROM agents a
            JOIN users u ON u.id = a.user_id
            ORDER BY u.full_name
            """,
            (rs, rowNum) -> new AgentChoice(rs.getLong("id"), rs.getString("full_name"))
        );
    }

    public List<ContributionRow> getContributions() {
        return jdbcTemplate.query(
            """
            SELECT c.id, u.full_name AS user_name, p.name AS product_name,
                   au.full_name AS agent_name, c.amount, c.payment_mode, c.status, c.reference_code
            FROM contributions c
            JOIN users u ON u.id = c.user_id
            LEFT JOIN products p ON p.id = c.product_id
            LEFT JOIN agents a ON a.id = c.agent_id
            LEFT JOIN users au ON au.id = a.user_id
            ORDER BY c.created_at DESC
            """,
            (rs, rowNum) -> new ContributionRow(
                rs.getLong("id"),
                rs.getString("user_name"),
                rs.getString("product_name"),
                rs.getString("agent_name"),
                rs.getDouble("amount"),
                rs.getString("payment_mode"),
                rs.getString("status"),
                rs.getString("reference_code")
            )
        );
    }

    public PageResult<ContributionRow> getContributionsPage(String q, String status, String paymentMode, int page, int size) {
        size = normalizePageSize(size);
        StringBuilder where = new StringBuilder(" WHERE 1=1 ");
        List<Object> args = new ArrayList<>();
        if (q != null && !q.isBlank()) {
            where.append(" AND (u.full_name LIKE ? OR COALESCE(p.name,'') LIKE ? OR COALESCE(c.reference_code,'') LIKE ?) ");
            String like = "%" + q.trim() + "%";
            args.add(like); args.add(like); args.add(like);
        }
        if (status != null && !status.isBlank()) {
            where.append(" AND c.status = ? ");
            args.add(status);
        }
        if (paymentMode != null && !paymentMode.isBlank()) {
            where.append(" AND c.payment_mode = ? ");
            args.add(paymentMode);
        }

        long total = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM contributions c JOIN users u ON u.id = c.user_id LEFT JOIN products p ON p.id = c.product_id LEFT JOIN agents a ON a.id = c.agent_id LEFT JOIN users au ON au.id = a.user_id " + where,
            args.toArray(),
            Long.class
        );
        List<Object> pageArgs = new ArrayList<>(args);
        pageArgs.add(size);
        pageArgs.add(page * size);

        List<ContributionRow> items = jdbcTemplate.query(
            "SELECT c.id, u.full_name AS user_name, p.name AS product_name, au.full_name AS agent_name, c.amount, c.payment_mode, c.status, c.reference_code FROM contributions c JOIN users u ON u.id = c.user_id LEFT JOIN products p ON p.id = c.product_id LEFT JOIN agents a ON a.id = c.agent_id LEFT JOIN users au ON au.id = a.user_id " + where + " ORDER BY c.created_at DESC LIMIT ? OFFSET ?",
            pageArgs.toArray(),
            (rs, rowNum) -> new ContributionRow(
                rs.getLong("id"),
                rs.getString("user_name"),
                rs.getString("product_name"),
                rs.getString("agent_name"),
                rs.getDouble("amount"),
                rs.getString("payment_mode"),
                rs.getString("status"),
                rs.getString("reference_code")
            )
        );
        return PageResult.of(items, page, size, total);
    }

    public void createContribution(long userId, Long productId, Long agentId, double amount, String paymentMode, String status, String referenceCode) {
        if (userId <= 0) throw new IllegalArgumentException("Client invalide");
        if (amount <= 0) throw new IllegalArgumentException("Montant invalide");
        requireText(paymentMode, "Mode de paiement requis");
        jdbcTemplate.update(
            """
            INSERT INTO contributions (user_id, product_id, agent_id, amount, payment_mode, status, reference_code, paid_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, IF(? = 'validated', NOW(), NULL))
            """,
            userId, productId, agentId, amount, paymentMode, status, referenceCode, status
        );
    }

    public void updateContributionStatus(long id, String status) {
        if (id <= 0) throw new IllegalArgumentException("ID cotisation invalide");
        jdbcTemplate.update(
            "UPDATE contributions SET status = ?, paid_at = IF(? = 'validated', NOW(), paid_at) WHERE id = ?",
            status, status, id
        );
    }

    public void updateContribution(long id, double amount, String paymentMode, String status, String referenceCode) {
        if (id <= 0) throw new IllegalArgumentException("ID cotisation invalide");
        if (amount <= 0) throw new IllegalArgumentException("Montant invalide");
        requireText(paymentMode, "Mode de paiement requis");
        jdbcTemplate.update(
            """
            UPDATE contributions
            SET amount = ?, payment_mode = ?, status = ?, reference_code = ?, paid_at = IF(? = 'validated', NOW(), paid_at)
            WHERE id = ?
            """,
            amount, paymentMode, status, referenceCode, status, id
        );
    }

    public void deleteContribution(long id) {
        if (id <= 0) throw new IllegalArgumentException("ID cotisation invalide");
        jdbcTemplate.update("DELETE FROM contributions WHERE id = ?", id);
    }

    private void requireText(String value, String message) {
        if (value == null || value.trim().isEmpty()) {
            throw new IllegalArgumentException(message);
        }
    }

    private String requireZoneName(long zoneId) {
        try {
            String n = jdbcTemplate.queryForObject(
                "SELECT name FROM zones WHERE id = ? AND active = TRUE",
                String.class,
                zoneId
            );
            if (n == null || n.isBlank()) {
                throw new IllegalArgumentException("Zone invalide ou inactive.");
            }
            return n.trim();
        } catch (DataAccessException ex) {
            throw new IllegalArgumentException("Zone introuvable.", ex);
        }
    }

    public List<ZoneChoice> listActiveZoneChoices() {
        return jdbcTemplate.query(
            "SELECT id, name FROM zones WHERE active = TRUE ORDER BY name",
            (rs, i) -> new ZoneChoice(rs.getLong("id"), rs.getString("name"))
        );
    }

    public List<ZoneListRow> listZonesWithCounts() {
        return jdbcTemplate.query(
            """
            SELECT z.id, z.name, z.description, z.active,
              (SELECT COUNT(*) FROM agents a WHERE a.zone_id = z.id) AS agents_count,
              (SELECT COUNT(DISTINCT u.id) FROM users u
               WHERE u.role_id = (SELECT id FROM roles WHERE code = 'client' LIMIT 1)
                 AND (
                   u.assigned_agent_user_id IN (SELECT ag.user_id FROM agents ag WHERE ag.zone_id = z.id)
                   OR u.id IN (
                     SELECT c.user_id FROM contributions c
                     INNER JOIN agents ag ON ag.id = c.agent_id
                     WHERE ag.zone_id = z.id
                   )
                 )) AS clients_count
            FROM zones z
            ORDER BY z.name
            """,
            (rs, i) -> new ZoneListRow(
                rs.getLong("id"),
                rs.getString("name"),
                rs.getString("description"),
                rs.getBoolean("active"),
                rs.getLong("agents_count"),
                rs.getLong("clients_count")
            )
        );
    }

    public Optional<ZoneListRow> findZone(long id) {
        try {
            ZoneListRow row = jdbcTemplate.queryForObject(
                """
                SELECT z.id, z.name, z.description, z.active,
                  (SELECT COUNT(*) FROM agents a WHERE a.zone_id = z.id) AS agents_count,
                  (SELECT COUNT(DISTINCT u.id) FROM users u
                   WHERE u.role_id = (SELECT id FROM roles WHERE code = 'client' LIMIT 1)
                     AND (
                       u.assigned_agent_user_id IN (SELECT ag.user_id FROM agents ag WHERE ag.zone_id = z.id)
                       OR u.id IN (
                         SELECT c.user_id FROM contributions c
                         INNER JOIN agents ag ON ag.id = c.agent_id
                         WHERE ag.zone_id = z.id
                       )
                     )) AS clients_count
                FROM zones z
                WHERE z.id = ?
                """,
                (rs, i) -> new ZoneListRow(
                    rs.getLong("id"),
                    rs.getString("name"),
                    rs.getString("description"),
                    rs.getBoolean("active"),
                    rs.getLong("agents_count"),
                    rs.getLong("clients_count")
                ),
                id
            );
            return Optional.ofNullable(row);
        } catch (DataAccessException ex) {
            return Optional.empty();
        }
    }

    public List<ZoneAgentShortcut> listAgentsInZone(long zoneId) {
        return jdbcTemplate.query(
            """
            SELECT a.id AS agent_id, u.full_name, u.city, a.active
            FROM agents a
            JOIN users u ON u.id = a.user_id
            WHERE a.zone_id = ?
            ORDER BY u.full_name
            """,
            (rs, i) -> new ZoneAgentShortcut(
                rs.getLong("agent_id"),
                rs.getString("full_name"),
                rs.getString("city"),
                rs.getBoolean("active")
            ),
            zoneId
        );
    }

    public List<ZoneClientShortcut> listClientsInZone(long zoneId) {
        return jdbcTemplate.query(
            """
            SELECT DISTINCT u.id, u.full_name, u.phone, u.city, u.status
            FROM users u
            WHERE u.role_id = (SELECT id FROM roles WHERE code = 'client' LIMIT 1)
              AND (
                u.assigned_agent_user_id IN (SELECT ag.user_id FROM agents ag WHERE ag.zone_id = ?)
                OR u.id IN (
                  SELECT c.user_id FROM contributions c
                  INNER JOIN agents ag ON ag.id = c.agent_id
                  WHERE ag.zone_id = ?
                )
              )
            ORDER BY u.full_name
            """,
            (rs, i) -> new ZoneClientShortcut(
                rs.getLong("id"),
                rs.getString("full_name"),
                rs.getString("phone"),
                rs.getString("city"),
                rs.getString("status")
            ),
            zoneId,
            zoneId
        );
    }

    @Transactional(rollbackFor = Exception.class)
    public long createZone(String name, String description) {
        requireText(name, "Nom de zone requis");
        jdbcTemplate.update(
            "INSERT INTO zones (name, description, active) VALUES (?, ?, TRUE)",
            name.trim(),
            emptyToNull(description)
        );
        Long lid = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        return lid == null ? 0L : lid;
    }

    @Transactional(rollbackFor = Exception.class)
    public void updateZone(long id, String name, String description, boolean active) {
        if (id <= 0) {
            throw new IllegalArgumentException("Zone invalide");
        }
        requireText(name, "Nom de zone requis");
        String trimmed = name.trim();
        jdbcTemplate.update(
            "UPDATE zones SET name = ?, description = ?, active = ? WHERE id = ?",
            trimmed,
            emptyToNull(description),
            active,
            id
        );
        jdbcTemplate.update("UPDATE agents SET zone = ? WHERE zone_id = ?", trimmed, id);
    }

    public void deleteZone(long id) {
        if (id <= 0) {
            throw new IllegalArgumentException("Zone invalide");
        }
        Long cnt = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM agents WHERE zone_id = ?", Long.class, id);
        if (cnt != null && cnt > 0) {
            throw new IllegalArgumentException("Impossible de supprimer : des agents sont encore affectés à cette zone.");
        }
        int n = jdbcTemplate.update("DELETE FROM zones WHERE id = ?", id);
        if (n == 0) {
            throw new IllegalArgumentException("Zone introuvable.");
        }
    }

    public record UserRow(
        long id,
        String fullName,
        String phone,
        long roleId,
        String role,
        String roleLabel,
        String city,
        String profession,
        String status,
        Long agentRecordId
    ) {}
    public record ProductCategoryRow(long id, String code, String label, int sortOrder, long productCount) {}

    public record ProductRow(
        long id,
        String code,
        String name,
        long categoryId,
        String category,
        double price,
        double minDailyContribution,
        String availability,
        String description,
        boolean featured,
        String imageMainPath,
        String imageDetail1Path,
        String imageDetail2Path,
        String imageUrl,
        String previewSrc
    ) {}
    public record AgentRow(long id, String fullName, String city, Long zoneId, String zone, boolean active, double collectedTotal) {}
    public record AgentCandidate(long userId, String fullName, String city, boolean promoteFromClient) {}
    public record ZoneChoice(long id, String name) {}
    public record ZoneListRow(long id, String name, String description, boolean active, long agentsCount, long clientsCount) {}
    public record ZoneAgentShortcut(long agentId, String fullName, String city, boolean active) {}
    public record ZoneClientShortcut(long userId, String fullName, String phone, String city, String status) {}
    public record UserChoice(long id, String fullName) {}
    public record ProductChoice(long id, String name) {}
    public record AgentChoice(long id, String fullName) {}
    public record ContributionRow(long id, String userName, String productName, String agentName, double amount, String paymentMode, String status, String referenceCode) {}
    public record AgentDetails(
        long agentId,
        long userId,
        String fullName,
        String phone,
        String city,
        String zone,
        boolean active,
        double objectiveAmount,
        double collectedAmount,
        long clientsCount,
        long validatedCount,
        long pendingCount,
        String matricule,
        String gender,
        String email,
        String personalAddress,
        String hireDate,
        String contractType,
        String emergencyContactName,
        String emergencyContactPhone,
        String emergencyContactRelation,
        String supervisorName,
        String supervisorPhone,
        String secondaryContactName,
        String secondaryContactPhone,
        String referencesNotes,
        String internalNotes,
        String idDocumentPath,
        String contractDocumentPath,
        String photoPath
    ) {}
    public record AgentClientRow(long userId, String fullName, String phone, String city, String profession, String status, double totalContributed, long contributionsCount, String lastContributionAt) {}
    public record ClientDetails(
        long id,
        String fullName,
        String phone,
        String city,
        String profession,
        String status,
        double totalContributed,
        long contributionsCount,
        double avgContribution,
        String lastContributionAt,
        long distinctProducts,
        long distinctAgents,
        String assignedAgentName,
        String assignedAgentPhone,
        Integer catchupPending,
        String catchupMonth,
        String uniqueCode
    ) {}
    public record ProductDetails(
        long id,
        String code,
        String name,
        String category,
        double price,
        double minDailyContribution,
        String availability,
        String description,
        String imageUrl,
        boolean featured,
        String imageMainPath,
        String imageDetail1Path,
        String imageDetail2Path,
        long selectedByClients,
        long contributionsCount,
        double totalAmount,
        double avgAmount
    ) {
        public String mainImageHref() {
            return pathOrLegacyHref(imageMainPath, imageUrl);
        }

        public String detail1Href() {
            return pathHref(imageDetail1Path);
        }

        public String detail2Href() {
            return pathHref(imageDetail2Path);
        }

        private static String pathOrLegacyHref(String path, String legacyUrl) {
            String h = pathHref(path);
            if (h != null && !h.isBlank()) {
                return h;
            }
            return legacyUrl != null && !legacyUrl.isBlank() ? legacyUrl : "";
        }

        private static String pathHref(String path) {
            if (path == null || path.isBlank()) {
                return "";
            }
            String n = path.trim().replace('\\', '/');
            return n.startsWith("/") ? n : "/" + n;
        }
    }
    public record ProductContributionRow(long contributionId, String userName, String agentName, double amount, String status, String createdAt) {}

    /** Dernières cotisations rattachées à l’agent (tableau central). */
    public record AgentContributionLine(
        long id,
        String clientName,
        String clientPhone,
        double amount,
        String paymentMode,
        String status,
        String referenceCode,
        String createdAt
    ) {}

    public List<AgentContributionLine> getRecentContributionsForAgent(long agentRowId, int limit) {
        int lim = Math.min(Math.max(limit, 1), 80);
        return jdbcTemplate.query(
            """
            SELECT c.id, u.full_name, u.phone, c.amount, c.payment_mode, c.status,
                   COALESCE(c.reference_code, '') AS reference_code,
                   c.created_at AS created_at
            FROM contributions c
            JOIN users u ON u.id = c.user_id
            WHERE c.agent_id = ?
            ORDER BY c.created_at DESC
            LIMIT ?
            """,
            (rs, i) -> new AgentContributionLine(
                rs.getLong("id"),
                rs.getString("full_name"),
                rs.getString("phone"),
                rs.getDouble("amount"),
                rs.getString("payment_mode"),
                rs.getString("status"),
                rs.getString("reference_code"),
                rs.getTimestamp("created_at") != null
                    ? rs.getTimestamp("created_at").toInstant().toString()
                    : ""
            ),
            agentRowId,
            lim
        );
    }

    public AgentDetails getAgentDetails(long agentId) {
        String sqlAgentDetails = """
            SELECT
              a.id AS agent_id,
              u.id AS user_id,
              u.full_name,
              u.phone,
              u.city,
              COALESCE(z.name, a.zone) AS zone_display,
              a.active,
              (%s) AS objective_amount,
              COALESCE((SELECT SUM(c.amount) FROM contributions c WHERE c.agent_id = a.id AND c.status = 'validated'), 0) AS collected_amount,
              (
                SELECT COUNT(DISTINCT cu.id)
                FROM users cu
                LEFT JOIN contributions cc ON cc.user_id = cu.id AND cc.agent_id = a.id
                WHERE cu.role_id = (SELECT id FROM roles WHERE code = 'client' LIMIT 1)
                  AND (cu.assigned_agent_user_id = a.user_id OR cc.id IS NOT NULL)
              ) AS clients_count,
              COALESCE((SELECT COUNT(*) FROM contributions c2 WHERE c2.agent_id = a.id AND c2.status = 'validated'), 0) AS validated_count,
              COALESCE((SELECT COUNT(*) FROM contributions c3 WHERE c3.agent_id = a.id AND c3.status = 'pending'), 0) AS pending_count,
              a.matricule,
              a.gender,
              a.email,
              a.personal_address,
              a.hire_date,
              a.contract_type,
              a.emergency_contact_name,
              a.emergency_contact_phone,
              a.emergency_contact_relation,
              a.supervisor_name,
              a.supervisor_phone,
              a.secondary_contact_name,
              a.secondary_contact_phone,
              a.references_notes,
              a.internal_notes,
              a.id_document_path,
              a.contract_document_path,
              a.photo_path
            FROM agents a
            JOIN users u ON u.id = a.user_id
            LEFT JOIN zones z ON z.id = a.zone_id
            WHERE a.id = ?
            """.formatted(terrainObjectiveSqlFragment());
        try {
            return jdbcTemplate.queryForObject(
                sqlAgentDetails,
                (rs, i) -> new AgentDetails(
                    rs.getLong("agent_id"),
                    rs.getLong("user_id"),
                    rs.getString("full_name"),
                    rs.getString("phone"),
                    rs.getString("city"),
                    rs.getString("zone_display"),
                    rs.getBoolean("active"),
                    rs.getDouble("objective_amount"),
                    rs.getDouble("collected_amount"),
                    rs.getLong("clients_count"),
                    rs.getLong("validated_count"),
                    rs.getLong("pending_count"),
                    rs.getString("matricule"),
                    rs.getString("gender"),
                    rs.getString("email"),
                    rs.getString("personal_address"),
                    rs.getString("hire_date"),
                    rs.getString("contract_type"),
                    rs.getString("emergency_contact_name"),
                    rs.getString("emergency_contact_phone"),
                    rs.getString("emergency_contact_relation"),
                    rs.getString("supervisor_name"),
                    rs.getString("supervisor_phone"),
                    rs.getString("secondary_contact_name"),
                    rs.getString("secondary_contact_phone"),
                    rs.getString("references_notes"),
                    rs.getString("internal_notes"),
                    rs.getString("id_document_path"),
                    rs.getString("contract_document_path"),
                    rs.getString("photo_path")
                ),
                agentId
            );
        } catch (DataAccessException ex) {
            log.warn("Fiche agent: fallback sans objectif terrain (raison: {})", ex.getMessage());
            String fallbackSql = """
                SELECT
                  a.id AS agent_id,
                  u.id AS user_id,
                  u.full_name,
                  u.phone,
                  u.city,
                  COALESCE(z.name, a.zone) AS zone_display,
                  a.active,
                  0 AS objective_amount,
                  COALESCE((SELECT SUM(c.amount) FROM contributions c WHERE c.agent_id = a.id AND c.status = 'validated'), 0) AS collected_amount,
                  (
                    SELECT COUNT(DISTINCT cu.id)
                    FROM users cu
                    LEFT JOIN contributions cc ON cc.user_id = cu.id AND cc.agent_id = a.id
                    WHERE cu.role_id = (SELECT id FROM roles WHERE code = 'client' LIMIT 1)
                      AND (cu.assigned_agent_user_id = a.user_id OR cc.id IS NOT NULL)
                  ) AS clients_count,
                  COALESCE((SELECT COUNT(*) FROM contributions c2 WHERE c2.agent_id = a.id AND c2.status = 'validated'), 0) AS validated_count,
                  COALESCE((SELECT COUNT(*) FROM contributions c3 WHERE c3.agent_id = a.id AND c3.status = 'pending'), 0) AS pending_count,
                  a.matricule,
                  a.gender,
                  a.email,
                  a.personal_address,
                  a.hire_date,
                  a.contract_type,
                  a.emergency_contact_name,
                  a.emergency_contact_phone,
                  a.emergency_contact_relation,
                  a.supervisor_name,
                  a.supervisor_phone,
                  a.secondary_contact_name,
                  a.secondary_contact_phone,
                  a.references_notes,
                  a.internal_notes,
                  a.id_document_path,
                  a.contract_document_path,
                  a.photo_path
                FROM agents a
                JOIN users u ON u.id = a.user_id
                LEFT JOIN zones z ON z.id = a.zone_id
                WHERE a.id = ?
                """;
            return jdbcTemplate.queryForObject(
                fallbackSql,
                (rs, i) -> new AgentDetails(
                    rs.getLong("agent_id"),
                    rs.getLong("user_id"),
                    rs.getString("full_name"),
                    rs.getString("phone"),
                    rs.getString("city"),
                    rs.getString("zone_display"),
                    rs.getBoolean("active"),
                    rs.getDouble("objective_amount"),
                    rs.getDouble("collected_amount"),
                    rs.getLong("clients_count"),
                    rs.getLong("validated_count"),
                    rs.getLong("pending_count"),
                    rs.getString("matricule"),
                    rs.getString("gender"),
                    rs.getString("email"),
                    rs.getString("personal_address"),
                    rs.getString("hire_date"),
                    rs.getString("contract_type"),
                    rs.getString("emergency_contact_name"),
                    rs.getString("emergency_contact_phone"),
                    rs.getString("emergency_contact_relation"),
                    rs.getString("supervisor_name"),
                    rs.getString("supervisor_phone"),
                    rs.getString("secondary_contact_name"),
                    rs.getString("secondary_contact_phone"),
                    rs.getString("references_notes"),
                    rs.getString("internal_notes"),
                    rs.getString("id_document_path"),
                    rs.getString("contract_document_path"),
                    rs.getString("photo_path")
                ),
                agentId
            );
        }
    }

    public List<AgentClientRow> getAgentClients(long agentId) {
        return jdbcTemplate.query(
            """
            SELECT
              u.id AS user_id, u.full_name, u.phone, u.city, u.profession, u.status,
              COALESCE(SUM(c.amount), 0) AS total_contributed,
              COUNT(c.id) AS contributions_count,
              MAX(c.created_at) AS last_contribution_at
            FROM users u
            LEFT JOIN contributions c ON c.user_id = u.id AND c.agent_id = ?
            WHERE u.role_id = (SELECT id FROM roles WHERE code = 'client' LIMIT 1)
              AND (u.assigned_agent_user_id = (SELECT user_id FROM agents WHERE id = ?) OR c.id IS NOT NULL)
            GROUP BY u.id, u.full_name, u.phone, u.city, u.profession, u.status
            ORDER BY total_contributed DESC, u.full_name
            """,
            (rs, i) -> new AgentClientRow(
                rs.getLong("user_id"),
                rs.getString("full_name"),
                rs.getString("phone"),
                rs.getString("city"),
                rs.getString("profession"),
                rs.getString("status"),
                rs.getDouble("total_contributed"),
                rs.getLong("contributions_count"),
                rs.getString("last_contribution_at")
            ),
            agentId, agentId
        );
    }

    public PageResult<UserRow> getClientsPage(String q, String city, String status, int page, int size) {
        size = normalizePageSize(size);
        StringBuilder where = new StringBuilder(" WHERE u.role_id = (SELECT id FROM roles WHERE code = 'client' LIMIT 1) ");
        List<Object> args = new ArrayList<>();
        if (q != null && !q.isBlank()) {
            where.append(" AND (u.full_name LIKE ? OR u.phone LIKE ? OR u.profession LIKE ?) ");
            String like = "%" + q.trim() + "%";
            args.add(like); args.add(like); args.add(like);
        }
        if (city != null && !city.isBlank()) {
            where.append(" AND u.city LIKE ? ");
            args.add("%" + city.trim() + "%");
        }
        if (status != null && !status.isBlank()) {
            where.append(" AND u.status = ? ");
            args.add(status);
        }
        long total = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM users u JOIN roles r ON r.id = u.role_id " + where,
            args.toArray(),
            Long.class
        );
        List<Object> pageArgs = new ArrayList<>(args);
        pageArgs.add(size);
        pageArgs.add(page * size);
        List<UserRow> items = jdbcTemplate.query(
            USER_ROW_SELECT + where + " ORDER BY u.created_at DESC LIMIT ? OFFSET ?",
            pageArgs.toArray(),
            this::mapUserRow
        );
        return PageResult.of(items, page, size, total);
    }

    public ClientDetails getClientDetails(long userId) {
        return jdbcTemplate.queryForObject(
            """
            SELECT
              u.id, u.full_name, u.phone, u.city, u.profession, u.status, u.unique_code,
              u.catchup_pending_cached, u.catchup_snapshot_month,
              ag.full_name AS assigned_agent_name, ag.phone AS assigned_agent_phone,
              COALESCE(SUM(c.amount), 0) AS total_contributed,
              COUNT(c.id) AS contributions_count,
              COALESCE(AVG(c.amount), 0) AS avg_contribution,
              MAX(c.created_at) AS last_contribution_at,
              COUNT(DISTINCT c.product_id) AS distinct_products,
              COUNT(DISTINCT c.agent_id) AS distinct_agents
            FROM users u
            LEFT JOIN users ag ON ag.id = u.assigned_agent_user_id
            LEFT JOIN contributions c ON c.user_id = u.id
            WHERE u.id = ?
            GROUP BY u.id, u.full_name, u.phone, u.city, u.profession, u.status, u.unique_code,
              u.catchup_pending_cached, u.catchup_snapshot_month, ag.full_name, ag.phone
            """,
            (rs, i) -> new ClientDetails(
                rs.getLong("id"),
                rs.getString("full_name"),
                rs.getString("phone"),
                rs.getString("city"),
                rs.getString("profession"),
                rs.getString("status"),
                rs.getDouble("total_contributed"),
                rs.getLong("contributions_count"),
                rs.getDouble("avg_contribution"),
                rs.getString("last_contribution_at"),
                rs.getLong("distinct_products"),
                rs.getLong("distinct_agents"),
                rs.getString("assigned_agent_name"),
                rs.getString("assigned_agent_phone"),
                rs.getObject("catchup_pending_cached") == null ? null : rs.getInt("catchup_pending_cached"),
                rs.getString("catchup_snapshot_month"),
                rs.getString("unique_code")
            ),
            userId
        );
    }

    public record ClientContributionRow(
        long id,
        String productName,
        String agentName,
        double amount,
        String paymentMode,
        String status,
        String referenceCode,
        String createdAt
    ) {}

    public List<ClientContributionRow> getRecentContributionsForClient(long clientUserId, int limit) {
        int lim = Math.max(1, Math.min(limit, 100));
        return jdbcTemplate.query(
            """
            SELECT c.id, c.amount, c.payment_mode, c.status, c.reference_code, c.created_at,
                   COALESCE(p.name, '—') AS product_name, COALESCE(au.full_name, '—') AS agent_name
            FROM contributions c
            LEFT JOIN products p ON p.id = c.product_id
            LEFT JOIN agents a ON a.id = c.agent_id
            LEFT JOIN users au ON au.id = a.user_id
            WHERE c.user_id = ?
            ORDER BY c.created_at DESC
            LIMIT ?
            """,
            (rs, i) -> new ClientContributionRow(
                rs.getLong("id"),
                rs.getString("product_name"),
                rs.getString("agent_name"),
                rs.getDouble("amount"),
                rs.getString("payment_mode"),
                rs.getString("status"),
                rs.getString("reference_code"),
                rs.getString("created_at")
            ),
            clientUserId,
            lim
        );
    }

    public int bulkValidatePendingContributions() {
        return jdbcTemplate.update(
            "UPDATE contributions SET status = 'validated', paid_at = NOW() WHERE status = 'pending'"
        );
    }

    public java.util.Optional<Path> resolveAgentDossierFile(long agentId, String kind) {
        try {
            var row = jdbcTemplate.queryForMap(
                "SELECT photo_path, id_document_path, contract_document_path FROM agents WHERE id = ?",
                agentId
            );
            String rel = switch (kind) {
                case "photo" -> (String) row.get("photo_path");
                case "identity" -> (String) row.get("id_document_path");
                case "contract" -> (String) row.get("contract_document_path");
                default -> null;
            };
            if (rel == null || rel.isBlank()) {
                return java.util.Optional.empty();
            }
            Path file = Path.of(rel.replace('\\', '/')).normalize();
            if (!file.isAbsolute()) {
                file = Path.of(".").resolve(file).normalize();
            }
            if (Files.isRegularFile(file)) {
                return java.util.Optional.of(file);
            }
            Path byName = Path.of("uploads", "agent-dossiers").resolve(file.getFileName()).normalize();
            if (Files.isRegularFile(byName)) {
                return java.util.Optional.of(byName);
            }
            return java.util.Optional.empty();
        } catch (EmptyResultDataAccessException ex) {
            return java.util.Optional.empty();
        }
    }

    public List<StatPoint> clientMonthlyCollections(long userId) {
        return jdbcTemplate.query(
            """
            SELECT DATE_FORMAT(created_at, '%Y-%m') AS label, COALESCE(SUM(amount), 0) AS value
            FROM contributions
            WHERE user_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 12 MONTH)
            GROUP BY DATE_FORMAT(created_at, '%Y-%m')
            ORDER BY label
            """,
            (rs, i) -> new StatPoint(rs.getString("label"), rs.getDouble("value")),
            userId
        );
    }

    public ProductDetails getProductDetails(long productId) {
        return jdbcTemplate.queryForObject(
            """
            SELECT
              p.id, p.code, p.name, pc.label AS category, p.price, p.min_daily_contribution, p.availability, p.description, p.image_url,
              p.featured, p.image_main_path, p.image_detail_1_path, p.image_detail_2_path,
              COUNT(DISTINCT c.user_id) AS selected_by_clients,
              COUNT(c.id) AS contributions_count,
              COALESCE(SUM(c.amount), 0) AS total_amount,
              COALESCE(AVG(c.amount), 0) AS avg_amount
            FROM products p
            JOIN product_categories pc ON pc.id = p.category_id
            LEFT JOIN contributions c ON c.product_id = p.id
            WHERE p.id = ?
            GROUP BY p.id, p.code, p.name, pc.label, p.price, p.min_daily_contribution, p.availability, p.description, p.image_url,
              p.featured, p.image_main_path, p.image_detail_1_path, p.image_detail_2_path
            """,
            (rs, i) -> new ProductDetails(
                rs.getLong("id"),
                rs.getString("code"),
                rs.getString("name"),
                rs.getString("category"),
                rs.getDouble("price"),
                rs.getDouble("min_daily_contribution"),
                rs.getString("availability"),
                rs.getString("description"),
                rs.getString("image_url"),
                rs.getBoolean("featured"),
                rs.getString("image_main_path"),
                rs.getString("image_detail_1_path"),
                rs.getString("image_detail_2_path"),
                rs.getLong("selected_by_clients"),
                rs.getLong("contributions_count"),
                rs.getDouble("total_amount"),
                rs.getDouble("avg_amount")
            ),
            productId
        );
    }

    private Path ensureAgentUploadRoot() throws IOException {
        Path root = Path.of("uploads", "agent-dossiers");
        Files.createDirectories(root);
        return root;
    }

    private String storeAgentFile(MultipartFile file, String prefix) throws IOException {
        if (file == null || file.isEmpty()) {
            return null;
        }
        String ext = "";
        String original = file.getOriginalFilename();
        if (original != null && original.contains(".")) {
            ext = original.substring(original.lastIndexOf('.'));
        }
        String name = prefix + "_" + LocalDate.now().format(DateTimeFormatter.BASIC_ISO_DATE) + "_" + UUID.randomUUID() + ext;
        Path target = ensureAgentUploadRoot().resolve(name);
        Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);
        return target.toString().replace("\\", "/");
    }

    /**
     * Crée un utilisateur agent + fiche agents avec dossier employé (pièces optionnelles).
     */
    @Transactional(rollbackFor = Exception.class)
    public long hireAgentDossier(
        String fullName,
        String phone,
        String mobilePin,
        String city,
        String profession,
        long zoneId,
        String gender,
        String email,
        String personalAddress,
        String hireDateStr,
        String contractType,
        String matricule,
        String emergencyContactName,
        String emergencyContactPhone,
        String emergencyContactRelation,
        String supervisorName,
        String supervisorPhone,
        String secondaryContactName,
        String secondaryContactPhone,
        String referencesNotes,
        String internalNotes,
        MultipartFile idDocument,
        MultipartFile contractDocument,
        MultipartFile photo
    ) throws IOException {
        requireText(fullName, "Nom complet requis");
        requireText(phone, "Téléphone requis");
        requireText(mobilePin, "Code PIN mobile requis");
        credentialHashService.validateMobileCredential(mobilePin);
        String hashedPin = credentialHashService.hashMobileCredential(mobilePin.trim());
        if (zoneId <= 0) {
            throw new IllegalArgumentException("Zone d'affectation requise");
        }
        String zoneName = requireZoneName(zoneId);
        String phoneTrim = phone.trim();
        Long exists = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM users WHERE phone = ?", Long.class, phoneTrim);
        if (exists != null && exists > 0) {
            throw new IllegalArgumentException("Ce numéro de téléphone est déjà utilisé.");
        }
        Long agentRoleId = jdbcTemplate.queryForObject("SELECT id FROM roles WHERE code = 'agent' LIMIT 1", Long.class);
        if (agentRoleId == null || agentRoleId <= 0) {
            throw new IllegalStateException("Rôle « agent » introuvable en base.");
        }

        String uniqueCode = "AG-" + phoneTrim.replaceAll("\\D", "");
        if (uniqueCode.length() < 6) {
            uniqueCode = "AG-" + System.currentTimeMillis();
        }

        java.sql.Date hireDate = null;
        if (hireDateStr != null && !hireDateStr.isBlank()) {
            try {
                hireDate = java.sql.Date.valueOf(LocalDate.parse(hireDateStr.trim()));
            } catch (Exception ex) {
                throw new IllegalArgumentException("Date d'embauche invalide (AAAA-MM-JJ).");
            }
        }

        String idPath = storeAgentFile(idDocument, "id");
        String contractPath = storeAgentFile(contractDocument, "contract");
        String photoPath = storeAgentFile(photo, "photo");

        jdbcTemplate.update(
            """
            INSERT INTO users (full_name, phone, role_id, city, profession, status, pin, secret_code, unique_code)
            VALUES (?, ?, ?, ?, ?, 'valide', ?, ?, ?)
            """,
            fullName.trim(),
            phoneTrim,
            agentRoleId,
            emptyToNull(city),
            emptyToNull(profession),
            hashedPin,
            hashedPin,
            uniqueCode
        );
        Long userId = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        if (userId == null || userId <= 0) {
            throw new IllegalStateException("Création utilisateur impossible.");
        }

        String mat = resolveAgentMatricule(matricule, userId);

        jdbcTemplate.update(
            """
            INSERT INTO agents (
              user_id, zone, zone_id, active, collected_total,
              matricule, gender, email, personal_address, hire_date, contract_type,
              emergency_contact_name, emergency_contact_phone, emergency_contact_relation,
              supervisor_name, supervisor_phone,
              secondary_contact_name, secondary_contact_phone,
              references_notes, internal_notes,
              id_document_path, contract_document_path, photo_path
            ) VALUES (?, ?, ?, TRUE, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            userId,
            zoneName,
            zoneId,
            0.0,
            mat,
            emptyToNull(gender),
            emptyToNull(email),
            emptyToNull(personalAddress),
            hireDate,
            emptyToNull(contractType),
            emptyToNull(emergencyContactName),
            emptyToNull(emergencyContactPhone),
            emptyToNull(emergencyContactRelation),
            emptyToNull(supervisorName),
            emptyToNull(supervisorPhone),
            emptyToNull(secondaryContactName),
            emptyToNull(secondaryContactPhone),
            emptyToNull(referencesNotes),
            emptyToNull(internalNotes),
            idPath,
            contractPath,
            photoPath
        );
        Long agentPk = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        return agentPk == null ? 0L : agentPk;
    }

    /**
     * Matricule saisi manuellement (unique) ou généré automatiquement : PF-AG-00001, etc.
     */
    private String resolveAgentMatricule(String matricule, long userId) {
        String mat = matricule == null ? null : matricule.trim();
        if (mat != null && !mat.isEmpty()) {
            Long mCount = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM agents WHERE matricule = ?",
                Long.class,
                mat
            );
            if (mCount != null && mCount > 0) {
                throw new IllegalArgumentException("Ce matricule interne est déjà attribué.");
            }
            return mat;
        }
        String base = "PF-AG-" + String.format("%05d", userId);
        String candidate = base;
        int suffix = 0;
        while (agentMatriculeExists(candidate)) {
            suffix++;
            candidate = base + "-" + suffix;
        }
        return candidate;
    }

    private boolean agentMatriculeExists(String matricule) {
        Long n = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM agents WHERE matricule = ?",
            Long.class,
            matricule
        );
        return n != null && n > 0;
    }

    private static String emptyToNull(String s) {
        if (s == null) {
            return null;
        }
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }

    public List<ProductContributionRow> getProductContributions(long productId) {
        return jdbcTemplate.query(
            """
            SELECT c.id AS contribution_id, u.full_name AS user_name, COALESCE(au.full_name, '-') AS agent_name,
                   c.amount, c.status, c.created_at
            FROM contributions c
            JOIN users u ON u.id = c.user_id
            LEFT JOIN agents a ON a.id = c.agent_id
            LEFT JOIN users au ON au.id = a.user_id
            WHERE c.product_id = ?
            ORDER BY c.created_at DESC
            LIMIT 80
            """,
            (rs, i) -> new ProductContributionRow(
                rs.getLong("contribution_id"),
                rs.getString("user_name"),
                rs.getString("agent_name"),
                rs.getDouble("amount"),
                rs.getString("status"),
                rs.getString("created_at")
            ),
            productId
        );
    }

    public record StatPoint(String label, double value) {}
    /** Taille par défaut des listes admin (lignes par page). */
    public static final int DEFAULT_PAGE_SIZE = 80;

    public static int normalizePageSize(int size) {
        if (size <= 0) {
            return DEFAULT_PAGE_SIZE;
        }
        return Math.min(size, 500);
    }

    public record PageResult<T>(List<T> items, int page, int size, long total, int totalPages) {
        public static <T> PageResult<T> of(List<T> items, int page, int size, long total) {
            int effectiveSize = normalizePageSize(size);
            int totalPages = total == 0
                ? 1
                : Math.max(1, (int) Math.ceil(total / (double) effectiveSize));
            return new PageResult<>(items, page, effectiveSize, total, totalPages);
        }

        /** Début de plage affichée (1-based), ex. 1 dans « 1–3 sur 3 ». */
        public long rangeStart() {
            if (total == 0 || items.isEmpty()) {
                return 0;
            }
            return (long) page * size + 1;
        }

        /** Fin de plage affichée, ex. 3 dans « 1–3 sur 3 ». */
        public long rangeEnd() {
            if (total == 0 || items.isEmpty()) {
                return 0;
            }
            return rangeStart() + items.size() - 1;
        }

        public int displayPage() {
            return total == 0 ? 1 : page + 1;
        }

        public int displayTotalPages() {
            return totalPages < 1 ? 1 : totalPages;
        }

        public boolean hasPrevious() {
            return page > 0;
        }

        public boolean hasNext() {
            return page + 1 < displayTotalPages();
        }

        /** URL de pagination avec filtres conservés (évite expressions Thymeleaf fragiles). */
        public String linkFor(String basePath, String filterQuery, int targetPage) {
            String path = basePath == null || basePath.isBlank() ? "/admin" : basePath.trim();
            String fq = filterQuery == null || filterQuery.isBlank() ? "" : "&" + filterQuery.trim();
            return path + "?page=" + Math.max(0, targetPage) + "&size=" + size + fq;
        }
    }
}
