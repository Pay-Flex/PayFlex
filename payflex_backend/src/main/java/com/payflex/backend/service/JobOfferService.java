package com.payflex.backend.service;

import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class JobOfferService {

    private static final long MAX_ATTACHMENT_BYTES = 15L * 1024 * 1024;

    private final JdbcTemplate jdbcTemplate;
    private final Path uploadRoot;

    public JobOfferService(JdbcTemplate jdbcTemplate) throws IOException {
        this.jdbcTemplate = jdbcTemplate;
        this.uploadRoot = Path.of("uploads", "job-offers").toAbsolutePath().normalize();
        Files.createDirectories(uploadRoot);
    }

    public record JobOfferRow(
        long id,
        String title,
        String summary,
        String description,
        String location,
        String profileRequirements,
        String startsAt,
        String endsAt,
        String startsAtInput,
        String endsAtInput,
        boolean active,
        int sortOrder,
        String updatedAt,
        String updatedBy,
        int attachmentCount
    ) {}

    public record JobOfferAttachmentRow(
        long id,
        long offerId,
        String fileUrl,
        String fileName,
        String mimeType,
        int sortOrder
    ) {}

    public List<JobOfferRow> listAllForAdmin() {
        return jdbcTemplate.query(
            """
            SELECT o.id, o.title, COALESCE(o.summary, '') AS summary, o.description,
                   COALESCE(o.location, '') AS location,
                   COALESCE(o.profile_requirements, '') AS profile_requirements,
                   DATE_FORMAT(o.starts_at, '%d/%m/%Y') AS starts_at,
                   DATE_FORMAT(o.ends_at, '%d/%m/%Y') AS ends_at,
                   DATE_FORMAT(o.starts_at, '%Y-%m-%d') AS starts_at_input,
                   DATE_FORMAT(o.ends_at, '%Y-%m-%d') AS ends_at_input,
                   o.active, o.sort_order,
                   DATE_FORMAT(o.updated_at, '%Y-%m-%d %H:%i') AS updated_at,
                   COALESCE(o.updated_by, '') AS updated_by,
                   (SELECT COUNT(*) FROM job_offer_attachments a WHERE a.offer_id = o.id) AS attachment_count
            FROM job_offers o
            ORDER BY o.sort_order ASC, o.id DESC
            """,
            (rs, i) -> mapJobOfferRow(rs, true)
        );
    }

    public List<Map<String, Object>> listActiveForMobile() {
        List<JobOfferRow> rows = jdbcTemplate.query(
            """
            SELECT o.id, o.title, COALESCE(o.summary, '') AS summary, o.description,
                   COALESCE(o.location, '') AS location,
                   COALESCE(o.profile_requirements, '') AS profile_requirements,
                   DATE_FORMAT(o.starts_at, '%d/%m/%Y') AS starts_at,
                   DATE_FORMAT(o.ends_at, '%d/%m/%Y') AS ends_at,
                   DATE_FORMAT(o.starts_at, '%Y-%m-%d') AS starts_at_input,
                   DATE_FORMAT(o.ends_at, '%Y-%m-%d') AS ends_at_input,
                   o.active, o.sort_order,
                   DATE_FORMAT(o.updated_at, '%Y-%m-%d %H:%i') AS updated_at,
                   COALESCE(o.updated_by, '') AS updated_by,
                   0 AS attachment_count
            FROM job_offers o
            WHERE o.active = TRUE
            ORDER BY o.sort_order ASC, o.id DESC
            """,
            (rs, i) -> mapJobOfferRow(rs, false)
        );
        List<Map<String, Object>> out = new ArrayList<>(rows.size());
        for (JobOfferRow row : rows) {
            out.add(toMobileSummary(row));
        }
        return out;
    }

    public Map<String, Object> getActiveForMobile(long id) {
        JobOfferRow row = findById(id).orElseThrow(() -> new IllegalArgumentException("Offre introuvable."));
        if (!row.active()) {
            throw new IllegalArgumentException("Offre indisponible.");
        }
        Map<String, Object> map = new LinkedHashMap<>(toMobileSummary(row));
        map.put("description", row.description());
        map.put("attachments", listAttachmentsForMobile(id));
        return map;
    }

    public java.util.Optional<JobOfferRow> findById(long id) {
        if (id <= 0) {
            return java.util.Optional.empty();
        }
        try {
            JobOfferRow row = jdbcTemplate.queryForObject(
                """
                SELECT o.id, o.title, COALESCE(o.summary, '') AS summary, o.description,
                       COALESCE(o.location, '') AS location,
                       COALESCE(o.profile_requirements, '') AS profile_requirements,
                       DATE_FORMAT(o.starts_at, '%d/%m/%Y') AS starts_at,
                       DATE_FORMAT(o.ends_at, '%d/%m/%Y') AS ends_at,
                       DATE_FORMAT(o.starts_at, '%Y-%m-%d') AS starts_at_input,
                       DATE_FORMAT(o.ends_at, '%Y-%m-%d') AS ends_at_input,
                       o.active, o.sort_order,
                       DATE_FORMAT(o.updated_at, '%Y-%m-%d %H:%i') AS updated_at,
                       COALESCE(o.updated_by, '') AS updated_by,
                       (SELECT COUNT(*) FROM job_offer_attachments a WHERE a.offer_id = o.id) AS attachment_count
                FROM job_offers o
                WHERE o.id = ?
                """,
                (rs, i) -> mapJobOfferRow(rs, true),
                id
            );
            return java.util.Optional.ofNullable(row);
        } catch (EmptyResultDataAccessException ex) {
            return java.util.Optional.empty();
        }
    }

    public Map<Long, List<JobOfferAttachmentRow>> attachmentsGroupedByOfferId() {
        List<JobOfferAttachmentRow> rows = jdbcTemplate.query(
            """
            SELECT id, offer_id, file_url, file_name, COALESCE(mime_type, '') AS mime_type, sort_order
            FROM job_offer_attachments
            ORDER BY offer_id ASC, sort_order ASC, id ASC
            """,
            (rs, i) -> new JobOfferAttachmentRow(
                rs.getLong("id"),
                rs.getLong("offer_id"),
                rs.getString("file_url"),
                rs.getString("file_name"),
                rs.getString("mime_type"),
                rs.getInt("sort_order")
            )
        );
        Map<Long, List<JobOfferAttachmentRow>> grouped = new LinkedHashMap<>();
        for (JobOfferAttachmentRow row : rows) {
            grouped.computeIfAbsent(row.offerId(), k -> new ArrayList<>()).add(row);
        }
        return grouped;
    }

    public List<JobOfferAttachmentRow> listAttachments(long offerId) {
        return jdbcTemplate.query(
            """
            SELECT id, offer_id, file_url, file_name, COALESCE(mime_type, '') AS mime_type, sort_order
            FROM job_offer_attachments
            WHERE offer_id = ?
            ORDER BY sort_order ASC, id ASC
            """,
            (rs, i) -> new JobOfferAttachmentRow(
                rs.getLong("id"),
                rs.getLong("offer_id"),
                rs.getString("file_url"),
                rs.getString("file_name"),
                rs.getString("mime_type"),
                rs.getInt("sort_order")
            ),
            offerId
        );
    }

    public long create(
        String title,
        String summary,
        String description,
        String location,
        String profileRequirements,
        String startsAt,
        String endsAt,
        boolean active,
        Integer sortOrder,
        String updatedBy
    ) {
        validateOfferFields(title, description);
        jdbcTemplate.update(
            """
            INSERT INTO job_offers (
              title, summary, description, location, profile_requirements,
              starts_at, ends_at, active, sort_order, updated_at, updated_by
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), ?)
            """,
            title.trim(),
            blankToNull(summary),
            description.trim(),
            blankToNull(location),
            blankToNull(profileRequirements),
            parseDate(startsAt),
            parseDate(endsAt),
            active,
            sortOrder == null ? 100 : sortOrder,
            updatedBy
        );
        Long id = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        return id == null ? 0L : id;
    }

    public void update(
        long id,
        String title,
        String summary,
        String description,
        String location,
        String profileRequirements,
        String startsAt,
        String endsAt,
        boolean active,
        Integer sortOrder,
        String updatedBy
    ) {
        if (id <= 0) {
            throw new IllegalArgumentException("Offre invalide.");
        }
        validateOfferFields(title, description);
        int n = jdbcTemplate.update(
            """
            UPDATE job_offers SET
              title = ?, summary = ?, description = ?, location = ?, profile_requirements = ?,
              starts_at = ?, ends_at = ?, active = ?, sort_order = ?, updated_at = NOW(), updated_by = ?
            WHERE id = ?
            """,
            title.trim(),
            blankToNull(summary),
            description.trim(),
            blankToNull(location),
            blankToNull(profileRequirements),
            parseDate(startsAt),
            parseDate(endsAt),
            active,
            sortOrder == null ? 100 : sortOrder,
            updatedBy,
            id
        );
        if (n == 0) {
            throw new IllegalArgumentException("Offre introuvable.");
        }
    }

    public void toggleActive(long id, String updatedBy) {
        if (id <= 0) {
            throw new IllegalArgumentException("Offre invalide.");
        }
        int n = jdbcTemplate.update(
            """
            UPDATE job_offers SET active = NOT active, updated_at = NOW(), updated_by = ?
            WHERE id = ?
            """,
            updatedBy,
            id
        );
        if (n == 0) {
            throw new IllegalArgumentException("Offre introuvable.");
        }
    }

    @Transactional
    public void delete(long id) {
        if (id <= 0) {
            throw new IllegalArgumentException("Offre invalide.");
        }
        List<String> urls = jdbcTemplate.query(
            "SELECT file_url FROM job_offer_attachments WHERE offer_id = ?",
            (rs, i) -> rs.getString(1),
            id
        );
        int n = jdbcTemplate.update("DELETE FROM job_offers WHERE id = ?", id);
        if (n == 0) {
            throw new IllegalArgumentException("Offre introuvable.");
        }
        for (String url : urls) {
            deleteStoredFile(url);
        }
    }

    public long addAttachment(long offerId, MultipartFile file) throws IOException {
        if (offerId <= 0) {
            throw new IllegalArgumentException("Offre invalide.");
        }
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("Fichier requis.");
        }
        if (file.getSize() > MAX_ATTACHMENT_BYTES) {
            throw new IllegalArgumentException("Fichier trop volumineux (maximum 15 Mo).");
        }
        Long exists = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM job_offers WHERE id = ?",
            Long.class,
            offerId
        );
        if (exists == null || exists == 0) {
            throw new IllegalArgumentException("Offre introuvable.");
        }

        String original = sanitizeFilename(file.getOriginalFilename());
        String ext = extensionOf(original);
        String storedName = "offer_" + offerId + "_" + Instant.now().toEpochMilli() + "_"
            + UUID.randomUUID().toString().substring(0, 8) + ext;

        Path offerDir = uploadRoot.resolve(String.valueOf(offerId)).normalize();
        if (!offerDir.startsWith(uploadRoot)) {
            throw new IllegalArgumentException("Chemin invalide.");
        }
        Files.createDirectories(offerDir);
        Path dest = offerDir.resolve(storedName).normalize();
        if (!dest.startsWith(offerDir)) {
            throw new IllegalArgumentException("Chemin invalide.");
        }
        file.transferTo(dest);

        String relativeUrl = "/uploads/job-offers/" + offerId + "/" + storedName;
        String mime = file.getContentType();
        Integer nextSort = jdbcTemplate.queryForObject(
            "SELECT COALESCE(MAX(sort_order), 0) + 1 FROM job_offer_attachments WHERE offer_id = ?",
            Integer.class,
            offerId
        );
        jdbcTemplate.update(
            """
            INSERT INTO job_offer_attachments (offer_id, file_url, file_name, mime_type, sort_order)
            VALUES (?, ?, ?, ?, ?)
            """,
            offerId,
            relativeUrl,
            original,
            mime,
            nextSort == null ? 1 : nextSort
        );
        Long id = jdbcTemplate.queryForObject("SELECT LAST_INSERT_ID()", Long.class);
        return id == null ? 0L : id;
    }

    public void deleteAttachment(long attachmentId) {
        if (attachmentId <= 0) {
            throw new IllegalArgumentException("Document invalide.");
        }
        List<String> urls = jdbcTemplate.query(
            "SELECT file_url FROM job_offer_attachments WHERE id = ?",
            (rs, i) -> rs.getString(1),
            attachmentId
        );
        int n = jdbcTemplate.update("DELETE FROM job_offer_attachments WHERE id = ?", attachmentId);
        if (n == 0) {
            throw new IllegalArgumentException("Document introuvable.");
        }
        for (String url : urls) {
            deleteStoredFile(url);
        }
    }

    private List<Map<String, Object>> listAttachmentsForMobile(long offerId) {
        List<JobOfferAttachmentRow> rows = listAttachments(offerId);
        List<Map<String, Object>> out = new ArrayList<>(rows.size());
        for (JobOfferAttachmentRow row : rows) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", row.id());
            m.put("file_url", row.fileUrl());
            m.put("file_name", row.fileName());
            m.put("mime_type", row.mimeType());
            out.add(m);
        }
        return out;
    }

    private static JobOfferRow mapJobOfferRow(java.sql.ResultSet rs, boolean useDbActive) throws java.sql.SQLException {
        return new JobOfferRow(
            rs.getLong("id"),
            rs.getString("title"),
            rs.getString("summary"),
            rs.getString("description"),
            rs.getString("location"),
            rs.getString("profile_requirements"),
            rs.getString("starts_at"),
            rs.getString("ends_at"),
            rs.getString("starts_at_input"),
            rs.getString("ends_at_input"),
            useDbActive ? rs.getBoolean("active") : true,
            rs.getInt("sort_order"),
            rs.getString("updated_at"),
            rs.getString("updated_by"),
            rs.getInt("attachment_count")
        );
    }

    private static Map<String, Object> toMobileSummary(JobOfferRow row) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", row.id());
        m.put("title", row.title());
        m.put("summary", row.summary());
        m.put("location", row.location());
        m.put("profile_requirements", row.profileRequirements());
        m.put("starts_at", row.startsAt());
        m.put("ends_at", row.endsAt());
        String period = formatPeriod(row.startsAt(), row.endsAt());
        if (!period.isBlank()) {
            m.put("period", period);
        }
        return m;
    }

    private static String formatPeriod(String startsAt, String endsAt) {
        boolean hasStart = startsAt != null && !startsAt.isBlank();
        boolean hasEnd = endsAt != null && !endsAt.isBlank();
        if (hasStart && hasEnd) {
            return startsAt + " — " + endsAt;
        }
        if (hasStart) {
            return "À partir du " + startsAt;
        }
        if (hasEnd) {
            return "Jusqu'au " + endsAt;
        }
        return "";
    }

    private static void validateOfferFields(String title, String description) {
        if (title == null || title.isBlank()) {
            throw new IllegalArgumentException("Titre requis.");
        }
        if (description == null || description.isBlank()) {
            throw new IllegalArgumentException("Description requise.");
        }
    }

    private static String blankToNull(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }

    private static LocalDate parseDate(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String v = raw.trim();
        if (v.matches("\\d{4}-\\d{2}-\\d{2}")) {
            return LocalDate.parse(v);
        }
        if (v.matches("\\d{2}/\\d{2}/\\d{4}")) {
            String[] p = v.split("/");
            return LocalDate.of(Integer.parseInt(p[2]), Integer.parseInt(p[1]), Integer.parseInt(p[0]));
        }
        throw new IllegalArgumentException("Date invalide : " + raw);
    }

    private void deleteStoredFile(String relativeUrl) {
        if (relativeUrl == null || relativeUrl.isBlank()) {
            return;
        }
        String normalized = relativeUrl.trim().replace('\\', '/');
        int idx = normalized.indexOf("uploads/job-offers/");
        if (idx < 0) {
            return;
        }
        String suffix = normalized.substring(idx + "uploads/job-offers/".length());
        Path target = uploadRoot.resolve(suffix).normalize();
        if (!target.startsWith(uploadRoot)) {
            return;
        }
        try {
            Files.deleteIfExists(target);
        } catch (IOException ignored) {
            // best effort
        }
    }

    private static String sanitizeFilename(String raw) {
        if (raw == null || raw.isBlank()) {
            return "document";
        }
        String name = Path.of(raw).getFileName().toString().trim();
        return name.isBlank() ? "document" : (name.length() > 200 ? name.substring(0, 200) : name);
    }

    private static String extensionOf(String filename) {
        int dot = filename.lastIndexOf('.');
        if (dot < 0 || dot == filename.length() - 1) {
            return ".bin";
        }
        return filename.substring(dot);
    }
}
