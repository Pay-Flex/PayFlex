package com.payflex.backend.service;

import com.payflex.backend.config.PayflexProperties;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;

@Service
public class MobileApiService {

    private static final String LOGIN_CREDENTIAL_SELECT = ", u.pin AS _pin_cred, u.account_password AS _password_cred\n";

    private final JdbcTemplate jdbcTemplate;
    private final PermissionService permissionService;
    private final ContributionWorkflowService contributionWorkflowService;
    private final ClientAdhesionService clientAdhesionService;
    private final CredentialHashService credentialHashService;
    private final UserInboxNotificationService inboxNotifications;
    private final PayflexProperties payflexProperties;
    private final ProductDeliveryService productDeliveryService;

    public MobileApiService(
        JdbcTemplate jdbcTemplate,
        PermissionService permissionService,
        ContributionWorkflowService contributionWorkflowService,
        ClientAdhesionService clientAdhesionService,
        CredentialHashService credentialHashService,
        UserInboxNotificationService inboxNotifications,
        PayflexProperties payflexProperties,
        ProductDeliveryService productDeliveryService
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.permissionService = permissionService;
        this.contributionWorkflowService = contributionWorkflowService;
        this.clientAdhesionService = clientAdhesionService;
        this.credentialHashService = credentialHashService;
        this.inboxNotifications = inboxNotifications;
        this.payflexProperties = payflexProperties;
        this.productDeliveryService = productDeliveryService;
    }

    public Map<String, Object> login(String identifier, String secret) {
        MobileLoginResolution resolution = resolveLogin(identifier, secret, null, null);
        return resolution.isSuccess() ? resolution.profile() : null;
    }

    public MobileLoginResolution resolveLogin(String identifier, String secret, Long expectedUserId) {
        return resolveLogin(identifier, secret, expectedUserId, null);
    }

    public MobileLoginResolution resolveLogin(String identifier, String secret, Long expectedUserId, String loginMode) {
        if (identifier == null || identifier.isBlank() || secret == null || secret.isBlank()) {
            return MobileLoginResolution.fail(
                "Indiquez votre identifiant (téléphone, nom ou e-mail) et votre mot de passe ou code PIN.",
                MobileLoginResolution.CODE_INVALID_CREDENTIALS
            );
        }
        String id = identifier.trim();
        String secretTrim = secret.trim();
        ParsedLoginIdentifier parsed = parseLoginIdentifier(id, loginMode);
        if (parsed.kind() == LoginIdentifierKind.UNSUPPORTED) {
            return MobileLoginResolution.fail(
                unsupportedIdentifierMessage(loginMode),
                MobileLoginResolution.CODE_INVALID_IDENTIFIER
            );
        }
        if (parsed.kind() == LoginIdentifierKind.PHONE
            && parsed.phoneDigits() != null
            && parsed.phoneDigits().length() < 8) {
            return MobileLoginResolution.fail(
                "Numéro incomplet : saisissez au moins 8 chiffres de votre numéro de téléphone.",
                MobileLoginResolution.CODE_INVALID_IDENTIFIER
            );
        }
        List<Map<String, Object>> rows = findIdentityCandidates(parsed);

        if (rows.isEmpty()) {
            return MobileLoginResolution.fail(
                identifierFailureMessageFor(parsed),
                MobileLoginResolution.CODE_INVALID_IDENTIFIER
            );
        }
        if (rows.size() > 1) {
            List<Map<String, Object>> narrowed = narrowByNameHint(rows, parsed.nameHint());
            if (narrowed.size() == 1) {
                rows = narrowed;
            } else {
                return MobileLoginResolution.fail(ambiguousMessageFor(parsed), MobileLoginResolution.CODE_AMBIGUOUS);
            }
        }

        Map<String, Object> row = new LinkedHashMap<>(rows.get(0));
        if (!rowMatchesSecret(row, secretTrim)) {
            return MobileLoginResolution.fail(
                secretFailureMessageFor(parsed),
                MobileLoginResolution.CODE_INVALID_SECRET
            );
        }
        row = stripCredentialFields(row);
        if (expectedUserId != null) {
            Object idObj = row.get("id");
            long uid = idObj instanceof Number n ? n.longValue() : 0L;
            if (uid != expectedUserId) {
                return MobileLoginResolution.fail(
                    "Session invalide ou compte introuvable.",
                    MobileLoginResolution.CODE_INVALID_CREDENTIALS
                );
            }
        }
        Object idVal = row.get("id");
        if (idVal instanceof Number n) {
            row.put("permissions", permissionService.permissionCodesForUser(n.longValue()));
        }
        clientAdhesionService.enrichProfileMap(row);
        productDeliveryService.enrichProfileMap(row);
        enrichProfilePhoto(row);
        enrichRegistrationRejectionNote(row);
        return MobileLoginResolution.success(row);
    }

    private void enrichRegistrationRejectionNote(Map<String, Object> row) {
        Object phoneObj = row.get("phone");
        if (phoneObj == null) return;
        try {
            List<Map<String, Object>> rows = jdbcTemplate.queryForList(
                """
                SELECT admin_note FROM registration_requests
                WHERE phone = ? AND status = 'rejected'
                ORDER BY updated_at DESC, created_at DESC LIMIT 1
                """,
                phoneObj.toString().trim()
            );
            if (!rows.isEmpty()) {
                Object note = rows.get(0).get("admin_note");
                if (note != null && !note.toString().isBlank()) {
                    row.put("registration_rejection_note", note.toString().trim());
                }
            }
        } catch (Exception ignored) {
            // noop
        }
    }

    /**
     * Mise à jour limitée du profil client depuis l'app mobile.
     */
    public void updateClientProfile(
        long userId,
        String city,
        String profession,
        String workplaceName,
        String workplaceAddress,
        String bossName,
        String bossPhone
    ) {
        jdbcTemplate.update(
            """
            UPDATE users SET
              city = COALESCE(NULLIF(TRIM(?), ''), city),
              profession = COALESCE(NULLIF(TRIM(?), ''), profession),
              workplace_name = NULLIF(TRIM(?), ''),
              workplace_address = NULLIF(TRIM(?), ''),
              boss_name = NULLIF(TRIM(?), ''),
              boss_phone = NULLIF(TRIM(?), '')
            WHERE id = ? AND role_id = (SELECT id FROM roles WHERE code = 'client' LIMIT 1)
            """,
            city,
            profession,
            workplaceName,
            workplaceAddress,
            bossName,
            bossPhone,
            userId
        );
    }

    /** Expose la photo d'inscription (chemin relatif /uploads/... pour l'app mobile). */
    private void enrichProfilePhoto(Map<String, Object> row) {
        String path = trimToNull(row.get("profile_photo_path"));
        if (path == null) {
            Object phoneObj = row.get("phone");
            if (phoneObj != null) {
                List<String> paths = jdbcTemplate.query(
                    """
                    SELECT profile_photo_path FROM registration_requests
                    WHERE phone = ? AND profile_photo_path IS NOT NULL AND TRIM(profile_photo_path) <> ''
                    ORDER BY created_at DESC LIMIT 1
                    """,
                    (rs, i) -> rs.getString(1),
                    phoneObj.toString().trim()
                );
                if (!paths.isEmpty()) {
                    path = trimToNull(paths.get(0));
                }
            }
        }
        row.remove("profile_photo_path");
        if (path != null) {
            row.put("profile_photo_url", resolveProductMediaUrl(normalizeUploadPath(path), null, null));
        }
    }

    /** Réduit un chemin disque éventuel en URL relative /uploads/... */
    private static String normalizeUploadPath(String path) {
        String n = path.replace('\\', '/').trim();
        int idx = n.indexOf("uploads/");
        if (idx >= 0) {
            return "/" + n.substring(idx);
        }
        return n.startsWith("/") ? n : "/" + n;
    }

    private enum LoginIdentifierKind {
        EMAIL, PHONE, NAME, UNSUPPORTED
    }

    private record ParsedLoginIdentifier(LoginIdentifierKind kind, String email, String phoneDigits, String nameHint) {}

    private ParsedLoginIdentifier parseLoginIdentifier(String raw, String loginMode) {
        String trimmed = raw.trim();
        String mode = loginMode == null ? "" : loginMode.trim().toLowerCase(Locale.ROOT);
        if ("email".equals(mode)) {
            String email = UserContactUniquenessService.normalizeEmail(trimmed);
            if (email == null || !trimmed.contains("@")) {
                return new ParsedLoginIdentifier(LoginIdentifierKind.UNSUPPORTED, null, null, null);
            }
            return new ParsedLoginIdentifier(LoginIdentifierKind.EMAIL, email, null, null);
        }
        if ("phone".equals(mode)) {
            String digits = normalizePhoneDigits(trimmed);
            return new ParsedLoginIdentifier(LoginIdentifierKind.PHONE, null, digits, null);
        }
        if ("name".equals(mode)) {
            String name = trimmed.replaceAll("\\s+", " ").trim();
            if (name.length() < 2) {
                return new ParsedLoginIdentifier(LoginIdentifierKind.UNSUPPORTED, null, null, null);
            }
            return new ParsedLoginIdentifier(LoginIdentifierKind.NAME, null, null, name);
        }
        if (trimmed.contains("@")) {
            String email = UserContactUniquenessService.normalizeEmail(trimmed);
            if (email == null) {
                return new ParsedLoginIdentifier(LoginIdentifierKind.UNSUPPORTED, null, null, null);
            }
            return new ParsedLoginIdentifier(LoginIdentifierKind.EMAIL, email, null, null);
        }
        String digits = normalizePhoneDigits(trimmed);
        String nameHint = trimmed.replaceAll("[+0-9\\-().\\s]+", " ").replaceAll("\\s+", " ").trim();
        if (nameHint.isEmpty()) {
            nameHint = null;
        }
        if (digits.length() >= 8) {
            return new ParsedLoginIdentifier(LoginIdentifierKind.PHONE, null, digits, nameHint);
        }
        if (nameHint != null && nameHint.length() >= 2) {
            return new ParsedLoginIdentifier(LoginIdentifierKind.NAME, null, null, nameHint);
        }
        return new ParsedLoginIdentifier(LoginIdentifierKind.UNSUPPORTED, null, null, null);
    }

    private static String unsupportedIdentifierMessage(String loginMode) {
        String mode = loginMode == null ? "" : loginMode.trim().toLowerCase(Locale.ROOT);
        return switch (mode) {
            case "phone" -> "Numéro incomplet : saisissez au moins 8 chiffres (ex. 90000000).";
            case "name" -> "Saisissez au moins 2 caractères de votre prénom ou nom.";
            case "email" -> "Saisissez une adresse e-mail valide.";
            default -> "Identifiant invalide. Utilisez le mode Téléphone, Nom ou E-mail.";
        };
    }

    private List<Map<String, Object>> findIdentityCandidates(ParsedLoginIdentifier parsed) {
        return switch (parsed.kind()) {
            case EMAIL -> findIdentityByEmail(parsed.email());
            case PHONE -> findIdentityByPhone(parsed.phoneDigits());
            case NAME -> findIdentityByName(parsed.nameHint());
            case UNSUPPORTED -> List.of();
        };
    }

    private boolean rowMatchesSecret(Map<String, Object> row, String rawSecret) {
        Object pinObj = row.get("_pin_cred");
        Object passObj = row.get("_password_cred");
        String pinStored = pinObj == null ? "" : String.valueOf(pinObj);
        String passStored = passObj == null ? "" : String.valueOf(passObj).trim();

        boolean pinOk = credentialHashService.matchesMobileCredential(rawSecret, pinStored);
        if (pinOk) {
            return true;
        }
        if (passStored.isEmpty() || "null".equalsIgnoreCase(passStored)) {
            return false;
        }
        return credentialHashService.matchesMobileCredential(rawSecret, passStored);
    }

    private List<Map<String, Object>> findIdentityByEmail(String email) {
        if (email == null || email.isBlank()) {
            return List.of();
        }
        List<Map<String, Object>> merged = new ArrayList<>();
        merged.addAll(jdbcTemplate.queryForList(
            LOGIN_USER_SELECT + LOGIN_CREDENTIAL_SELECT + LOGIN_FROM
                + " WHERE LOWER(TRIM(u.email)) = ?"
                + " AND " + LOGIN_STATUS_FILTER
                + " LIMIT 10",
            email
        ));
        merged.addAll(findIdentityByAgentEmail(email));
        return dedupeByUserId(merged);
    }

    private List<Map<String, Object>> findIdentityByAgentEmail(String email) {
        return jdbcTemplate.queryForList(
            LOGIN_USER_SELECT + LOGIN_CREDENTIAL_SELECT + LOGIN_FROM
                + " INNER JOIN agents ar ON ar.user_id = u.id"
                + " WHERE LOWER(TRIM(ar.email)) = ?"
                + " AND " + LOGIN_STATUS_FILTER
                + " LIMIT 10",
            email
        );
    }

    private static List<Map<String, Object>> dedupeByUserId(List<Map<String, Object>> rows) {
        Map<Object, Map<String, Object>> byId = new LinkedHashMap<>();
        for (Map<String, Object> row : rows) {
            byId.putIfAbsent(row.get("id"), row);
        }
        return new ArrayList<>(byId.values());
    }

    private static final String PHONE_NORM_SQL =
        "REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TRIM(u.phone), ' ', ''), '-', ''), '(', ''), ')', ''), '+', '')";

    private List<Map<String, Object>> findIdentityByPhone(String digits) {
        if (digits == null || digits.length() < 8) {
            return List.of();
        }
        String suffix8 = phoneSuffix8(digits);
        return jdbcTemplate.queryForList(
            LOGIN_USER_SELECT + LOGIN_CREDENTIAL_SELECT + LOGIN_FROM
                + " WHERE " + LOGIN_STATUS_FILTER
                + " AND (" + PHONE_NORM_SQL + " = ? OR RIGHT(" + PHONE_NORM_SQL + ", 8) = ?)"
                + " LIMIT 10",
            digits, suffix8
        );
    }

    private List<Map<String, Object>> findIdentityByName(String nameQuery) {
        if (nameQuery == null || nameQuery.isBlank()) {
            return List.of();
        }
        String lower = nameQuery.trim().toLowerCase(Locale.ROOT);
        if (lower.length() < 2) {
            return List.of();
        }
        List<Map<String, Object>> broad = jdbcTemplate.queryForList(
            LOGIN_USER_SELECT + LOGIN_CREDENTIAL_SELECT + LOGIN_FROM
                + " WHERE " + LOGIN_STATUS_FILTER
                + " AND LOWER(TRIM(u.full_name)) LIKE ?"
                + " LIMIT 20",
            "%" + lower + "%"
        );
        if (broad.size() <= 1) {
            return broad;
        }
        List<Map<String, Object>> narrowed = narrowByNameHint(broad, nameQuery);
        return narrowed.isEmpty() ? broad : narrowed;
    }

    private Map<String, Object> stripCredentialFields(Map<String, Object> row) {
        Map<String, Object> copy = new LinkedHashMap<>(row);
        copy.remove("_pin_cred");
        copy.remove("_password_cred");
        copy.remove("_credential");
        copy.remove("pin");
        copy.remove("secret_code");
        copy.remove("account_password");
        return copy;
    }

    /**
     * Si l'utilisateur a saisi nom + numéro, affine une liste ambiguë par téléphone.
     */
    private List<Map<String, Object>> narrowByNameHint(List<Map<String, Object>> rows, String nameHint) {
        if (nameHint == null || nameHint.isBlank() || rows.size() <= 1) {
            return rows;
        }
        List<String> tokens = Arrays.stream(nameHint.toLowerCase(Locale.ROOT).split("\\s+"))
            .map(String::trim)
            .filter(t -> t.length() >= 2)
            .toList();
        if (tokens.isEmpty()) {
            return rows;
        }
        return rows.stream()
            .filter(row -> {
                String fullName = String.valueOf(row.getOrDefault("full_name", "")).toLowerCase(Locale.ROOT);
                String padded = " " + fullName.trim() + " ";
                for (String token : tokens) {
                    if (!padded.contains(" " + token + " ")
                        && !fullName.equals(token)
                        && !fullName.startsWith(token + " ")
                        && !fullName.endsWith(" " + token)) {
                        return false;
                    }
                }
                return true;
            })
            .collect(Collectors.toList());
    }

    private static String identifierFailureMessageFor(ParsedLoginIdentifier parsed) {
        return switch (parsed.kind()) {
            case PHONE ->
                "Aucun compte avec ce numéro de téléphone. Vérifiez le numéro (8 chiffres minimum, ex. 90000000).";
            case EMAIL -> "Aucun compte avec cet e-mail. Vérifiez l'adresse ou inscrivez-vous.";
            case NAME -> "Aucun compte avec ce nom. Vérifiez l'orthographe ou connectez-vous avec votre numéro.";
            case UNSUPPORTED ->
                "Identifiant invalide. Utilisez le mode Téléphone, Nom ou E-mail.";
        };
    }

    private static String secretFailureMessageFor(ParsedLoginIdentifier parsed) {
        return switch (parsed.kind()) {
            case PHONE -> "Mot de passe ou code PIN incorrect pour ce numéro.";
            case EMAIL -> "Mot de passe ou code PIN incorrect pour cet e-mail.";
            case NAME -> "Mot de passe ou code PIN incorrect pour ce nom.";
            case UNSUPPORTED -> "Mot de passe ou code PIN incorrect.";
        };
    }

    private static String ambiguousMessageFor(ParsedLoginIdentifier parsed) {
        return switch (parsed.kind()) {
            case PHONE -> "Plusieurs comptes correspondent à ce numéro. Contactez le support PayFlex.";
            case EMAIL -> "Plusieurs comptes sont associés à cet e-mail. Contactez l'administration PayFlex.";
            case NAME -> "Plusieurs comptes correspondent à ce nom. Précisez ou utilisez votre numéro de téléphone.";
            case UNSUPPORTED -> "Identifiant ambigu. Utilisez votre numéro de téléphone complet.";
        };
    }

    private static String phoneSuffix8(String digits) {
        if (digits == null || digits.length() <= 8) {
            return digits == null ? "" : digits;
        }
        return digits.substring(digits.length() - 8);
    }

    private static final String LOGIN_USER_SELECT = """
        SELECT u.id, u.full_name, r.code AS role, u.city, u.profession, u.phone, u.status, u.gender,
               u.unique_code, u.assigned_agent_user_id,
               u.adhesion_fee_paid, u.adhesion_dispute_open, u.assiduity_badge, u.self_managed,
               NULLIF(TRIM(u.profile_photo_path), '') AS profile_photo_path,
               NULLIF(TRIM(u.workplace_name), '') AS workplace_name,
               NULLIF(TRIM(u.workplace_address), '') AS workplace_address,
               NULLIF(TRIM(u.boss_name), '') AS boss_name,
               NULLIF(TRIM(u.boss_phone), '') AS boss_phone,
               ag.full_name AS assigned_agent_name, ag.phone AS assigned_agent_phone
        """;

    private static final String LOGIN_FROM = """
        FROM users u
        JOIN roles r ON r.id = u.role_id
        LEFT JOIN users ag ON ag.id = u.assigned_agent_user_id
        """;

    /** Connexion mobile : comptes en attente de validation admin autorisés (parcours lecture seule côté app). */
    private static final String LOGIN_STATUS_FILTER = "u.status <> 'bloque'";

    /**
     * Profil mobile : statut compte, agent assigné (après validation admin), etc.
     * Identifiant : numéro de téléphone (8 chiffres minimum) ou e-mail.
     * Secret : code PIN ou code secret (mot de passe cotisation saisi à l'inscription).
     *
     * @param expectedUserId si non null, impose que l'utilisateur trouvé ait cet id (sécurité légère côté app).
     */
    public Map<String, Object> profileByCredentials(String identifier, String secret, Long expectedUserId) {
        MobileLoginResolution resolution = resolveLogin(identifier, secret, expectedUserId);
        return resolution.isSuccess() ? resolution.profile() : null;
    }

    public List<Map<String, Object>> productsForMobile() {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(
            """
            SELECT
              CONCAT('prod_', p.id) AS id,
              p.name,
              pc.label AS category,
              pc.code AS category_code,
              p.price,
              p.min_daily_contribution AS daily_min,
              CASE WHEN p.featured THEN 1 ELSE 0 END AS is_featured,
              NULLIF(TRIM(p.image_main_path), '') AS image_main_path,
              NULLIF(TRIM(p.image_detail_1_path), '') AS image_detail_1_path,
              NULLIF(TRIM(p.image_detail_2_path), '') AS image_detail_2_path,
              NULLIF(TRIM(p.image_url), '') AS image_url,
              COALESCE(p.description, 'Équipement professionnel PayFlex') AS description
            FROM products p
            JOIN product_categories pc ON pc.id = p.category_id
            ORDER BY p.created_at DESC
            """
        );
        for (Map<String, Object> row : rows) {
            enrichMobileProductImages(row);
        }
        return rows;
    }

    private static void enrichMobileProductImages(Map<String, Object> row) {
        String catCode = Objects.toString(row.get("category_code"), "");
        String mainPath = trimToNull(row.get("image_main_path"));
        String legacy = trimToNull(row.get("image_url"));
        String d1Path = trimToNull(row.get("image_detail_1_path"));
        String d2Path = trimToNull(row.get("image_detail_2_path"));
        String fallback = categoryFallbackImage(catCode);
        String display = resolveProductMediaUrl(mainPath, legacy, fallback);
        row.put("image_url", display);
        String d1 = resolveProductMediaUrl(d1Path, null, null);
        String d2 = resolveProductMediaUrl(d2Path, null, null);
        if (d1 != null) {
            row.put("image_detail_1_url", d1);
        }
        if (d2 != null) {
            row.put("image_detail_2_url", d2);
        }
        java.util.List<String> gallery = new java.util.ArrayList<>();
        addGalleryUrl(gallery, display);
        addGalleryUrl(gallery, d1);
        addGalleryUrl(gallery, d2);
        row.put("gallery_urls", gallery);
    }

    private static void addGalleryUrl(java.util.List<String> gallery, String url) {
        if (url == null || url.isBlank()) {
            return;
        }
        if (!gallery.contains(url)) {
            gallery.add(url);
        }
    }

    private static String resolveProductMediaUrl(String storedPath, String legacyUrl, String fallback) {
        if (legacyUrl != null && (legacyUrl.startsWith("http://") || legacyUrl.startsWith("https://"))) {
            return legacyUrl;
        }
        if (storedPath != null) {
            String n = storedPath.replace('\\', '/').trim();
            return n.startsWith("/") ? n : "/" + n;
        }
        if (legacyUrl != null) {
            String n = legacyUrl.replace('\\', '/').trim();
            if (n.startsWith("http://") || n.startsWith("https://")) {
                return n;
            }
            return n.startsWith("/") ? n : "/" + n;
        }
        return fallback;
    }

    private static String trimToNull(Object v) {
        if (v == null) {
            return null;
        }
        String s = v.toString().trim();
        return s.isEmpty() ? null : s;
    }

    private static String categoryFallbackImage(String code) {
        return switch (code) {
            case "couture" -> "https://images.unsplash.com/photo-1521572267360-ee0c2909d518?w=800&q=80";
            case "coiffure" -> "https://images.unsplash.com/photo-1560066984-138dadb4c035?w=800&q=80";
            case "menuiserie" -> "https://images.unsplash.com/photo-1513467655676-561b7d489a88?w=800&q=80";
            case "maconnerie" -> "https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800&q=80";
            default -> "https://images.unsplash.com/photo-1581092786450-7ef25f140997?w=800&q=80";
        };
    }

    public List<Map<String, Object>> productCategoriesForMobile() {
        return jdbcTemplate.queryForList(
            """
            SELECT id, code, label
            FROM product_categories
            ORDER BY sort_order ASC, label ASC
            """
        );
    }

    public long createContribution(
        long userId,
        Long productId,
        Long agentId,
        double amount,
        String paymentMode,
        Integer catchupYear,
        Integer catchupMonth,
        Integer catchupDay
    ) {
        Long resolvedAgentId = agentId;
        if (resolvedAgentId == null) {
            resolvedAgentId = contributionWorkflowService.findAgentRowIdForClient(userId);
        }
        String ref = "PF-MOB-" + System.currentTimeMillis();
        jdbcTemplate.update(
            """
            INSERT INTO contributions (
                user_id, product_id, agent_id, amount, payment_mode, status, reference_code, paid_at,
                catchup_year, catchup_month, catchup_day
            )
            VALUES (?, ?, ?, ?, ?, 'pending', ?, NULL, ?, ?, ?)
            """,
            userId, productId, resolvedAgentId, amount, paymentMode, ref,
            catchupYear, catchupMonth, catchupDay
        );
        Long newId = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        long contributionId = newId == null ? 0L : newId;
        if (contributionId > 0) {
            contributionWorkflowService.notifyContributionPendingDeclaration(
                userId, contributionId, amount, paymentMode
            );
        }
        return contributionId;
    }

    public Long findContributionUserId(long contributionId) {
        try {
            return jdbcTemplate.queryForObject(
                "SELECT user_id FROM contributions WHERE id = ?",
                Long.class,
                contributionId
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    public String referenceCodeForContribution(long contributionId) {
        try {
            return jdbcTemplate.queryForObject(
                "SELECT reference_code FROM contributions WHERE id = ?",
                String.class,
                contributionId
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    public List<Map<String, Object>> contributionHistoryForClient(long userId) {
        return jdbcTemplate.queryForList(
            """
            SELECT
              c.id,
              c.amount,
              c.payment_mode,
              c.status,
              c.reference_code,
              c.created_at,
              c.rejection_reason,
              c.catchup_year,
              c.catchup_month,
              c.catchup_day,
              c.product_id,
              p.name AS product_name,
              p.price AS product_price,
              p.min_daily_contribution AS product_daily_min
            FROM contributions c
            LEFT JOIN products p ON p.id = c.product_id
            WHERE c.user_id = ?
            ORDER BY c.id DESC
            """,
            userId
        );
    }

    /**
     * Collecte espèces saisie par un agent sur le terrain.
     * Statut {@code pending} : validation au centre après rapprochement fin de journée.
     * Idempotence via {@code referenceCode} unique.
     */
    public long createAgentCashContribution(
        long clientUserId,
        Long productId,
        long agentRowId,
        double amount,
        String paymentMode,
        String referenceCode,
        Integer catchupYear,
        Integer catchupMonth,
        Integer catchupDay
    ) {
        String ref = referenceCode != null && !referenceCode.isBlank()
            ? referenceCode.trim()
            : "PF-AGENT-" + System.currentTimeMillis();
        List<Long> existing = jdbcTemplate.query(
            "SELECT id FROM contributions WHERE reference_code = ? LIMIT 1",
            (rs, i) -> rs.getLong(1),
            ref
        );
        if (!existing.isEmpty()) {
            return existing.get(0);
        }
        jdbcTemplate.update(
            """
            INSERT INTO contributions (
                user_id, product_id, agent_id, amount, payment_mode, status, reference_code, paid_at,
                catchup_year, catchup_month, catchup_day
            )
            VALUES (?, ?, ?, ?, ?, 'pending', ?, NULL, ?, ?, ?)
            """,
            clientUserId, productId, agentRowId, amount, paymentMode, ref,
            catchupYear, catchupMonth, catchupDay
        );
        return jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
    }

    public Long findAgentRowIdByUserId(long agentUserId) {
        try {
            return jdbcTemplate.queryForObject(
                "SELECT id FROM agents WHERE user_id = ? LIMIT 1",
                Long.class,
                agentUserId
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    /**
     * Résout l’id utilisateur (compte client) à partir du numéro affiché sur le terminal agent.
     */
    public long findClientUserIdByPhone(String phoneRaw) {
        if (phoneRaw == null || phoneRaw.isBlank()) {
            return 0L;
        }
        String trimmed = phoneRaw.trim();
        String digits = normalizePhoneDigits(trimmed);
        String digitsCompare = digits.isEmpty() ? trimmed : digits;
        List<Long> ids = jdbcTemplate.query(
            """
            SELECT u.id FROM users u
            INNER JOIN roles r ON r.id = u.role_id
            WHERE r.code = 'client'
              AND (u.status IS NULL OR LOWER(u.status) <> 'bloque')
              AND (
                TRIM(u.phone) = ?
                OR REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(u.phone, ' ', ''), '-', ''), '(', ''), ')', ''), '+', '') = ?
              )
            LIMIT 2
            """,
            (rs, i) -> rs.getLong(1),
            trimmed,
            digitsCompare
        );
        if (ids.size() != 1) {
            return 0L;
        }
        return ids.get(0);
    }

    public boolean verifyClientPin(long clientUserId, String clientPin) {
        if (clientUserId <= 0 || clientPin == null || clientPin.isBlank()) {
            return false;
        }
        try {
            Map<String, Object> row = jdbcTemplate.queryForMap(
                """
                SELECT u.pin, u.secret_code
                FROM users u
                INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
                WHERE u.id = ?
                LIMIT 1
                """,
                clientUserId
            );
            String pinStored = row.get("pin") != null ? row.get("pin").toString() : "";
            String secretStored = row.get("secret_code") != null ? row.get("secret_code").toString() : "";
            String submitted = clientPin.trim();
            if (credentialHashService.matchesMobilePin(submitted, pinStored)) {
                return true;
            }
            return credentialHashService.matchesMobilePin(submitted, secretStored);
        } catch (EmptyResultDataAccessException ex) {
            return false;
        }
    }

    public boolean clientUserExists(long clientUserId) {
        if (clientUserId <= 0) {
            return false;
        }
        Long n = jdbcTemplate.queryForObject(
            """
            SELECT COUNT(*) FROM users u
            INNER JOIN roles r ON r.id = u.role_id AND r.code = 'client'
            WHERE u.id = ?
            """,
            Long.class,
            clientUserId
        );
        return n != null && n > 0;
    }

    public boolean isClientAssignedToAgent(long clientUserId, long agentUserId) {
        Long assigned = jdbcTemplate.query(
            """
            SELECT assigned_agent_user_id FROM users u
            INNER JOIN roles r ON r.id = u.role_id
            WHERE u.id = ? AND r.code = 'client'
            """,
            rs -> {
                if (!rs.next()) {
                    return null;
                }
                Object v = rs.getObject(1);
                return v instanceof Number n ? n.longValue() : null;
            },
            clientUserId
        );
        return assigned != null && assigned == agentUserId;
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

    /** Snapshot carnet mobile : jours encore en « rattrapage » pour alertes admin + inbox. */
    public void updateCatchupPendingSnapshot(long userId, int orangeDays, String yearMonth) {
        String ym = yearMonth == null || yearMonth.isBlank() ? null : yearMonth.trim();
        jdbcTemplate.update(
            "UPDATE users SET catchup_pending_cached = ?, catchup_snapshot_month = ? WHERE id = ?",
            orangeDays,
            ym,
            userId
        );
        int threshold = payflexProperties.getCatchupAlertThreshold();
        if (threshold > 0) {
            inboxNotifications.maybeNotifyCatchupAlert(
                userId,
                orangeDays,
                ym != null ? ym : java.time.YearMonth.now().toString(),
                threshold
            );
        }
    }
}
