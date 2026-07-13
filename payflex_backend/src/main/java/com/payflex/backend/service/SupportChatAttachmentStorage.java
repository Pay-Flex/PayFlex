package com.payflex.backend.service;

import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

@Service
public class SupportChatAttachmentStorage {

    private static final long MAX_BYTES = 15L * 1024 * 1024;

    private static final Set<String> IMAGE_EXT = Set.of("jpg", "jpeg", "png", "gif", "webp", "heic", "heif");
    private static final Set<String> AUDIO_EXT = Set.of("mp3", "m4a", "aac", "wav", "ogg", "webm", "opus", "amr", "3gp");
    private static final Set<String> DOC_EXT = Set.of(
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "csv", "rtf", "odt", "ods"
    );

    private final Path uploadRoot;

    public SupportChatAttachmentStorage() throws IOException {
        this.uploadRoot = Path.of("uploads", "support-chat").toAbsolutePath().normalize();
        Files.createDirectories(uploadRoot);
    }

    public record StoredFile(String relativeUrl, String kind, String originalName, String mime) {}

    public StoredFile store(MultipartFile file, long userId) throws IOException {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("Fichier requis.");
        }
        if (file.getSize() > MAX_BYTES) {
            throw new IllegalArgumentException("Fichier trop volumineux (maximum 15 Mo).");
        }
        if (userId <= 0) {
            throw new IllegalArgumentException("Client invalide.");
        }

        String original = sanitizeFilename(file.getOriginalFilename());
        String mime = resolveMime(file.getContentType(), original);
        String kind = resolveKind(mime, original);
        String ext = extensionOf(original, kind, mime);
        String storedName = "chat_" + Instant.now().toEpochMilli() + "_"
            + UUID.randomUUID().toString().substring(0, 8) + ext;

        Path userDir = uploadRoot.resolve(String.valueOf(userId)).normalize();
        if (!userDir.startsWith(uploadRoot)) {
            throw new IllegalArgumentException("Chemin invalide.");
        }
        Files.createDirectories(userDir);

        Path dest = userDir.resolve(storedName).normalize();
        if (!dest.startsWith(userDir)) {
            throw new IllegalArgumentException("Chemin invalide.");
        }
        file.transferTo(dest);

        String relativeUrl = "/uploads/support-chat/" + userId + "/" + storedName;
        return new StoredFile(relativeUrl, kind, original, mime);
    }

    public void deleteIfPresent(String relativeUrl) {
        if (relativeUrl == null || relativeUrl.isBlank()) {
            return;
        }
        String normalized = relativeUrl.trim().replace('\\', '/');
        int idx = normalized.indexOf("uploads/support-chat/");
        if (idx < 0) {
            return;
        }
        String suffix = normalized.substring(idx + "uploads/support-chat/".length());
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
            return "fichier";
        }
        String name = Path.of(raw).getFileName().toString().trim();
        if (name.isBlank()) {
            return "fichier";
        }
        return name.length() > 200 ? name.substring(0, 200) : name;
    }

    private static String resolveMime(String contentType, String filename) {
        if (contentType != null && !contentType.isBlank() && !"application/octet-stream".equalsIgnoreCase(contentType)) {
            return contentType.split(";")[0].trim().toLowerCase(Locale.ROOT);
        }
        String ext = extensionOnly(filename);
        return switch (ext) {
            case "jpg", "jpeg" -> "image/jpeg";
            case "png" -> "image/png";
            case "gif" -> "image/gif";
            case "webp" -> "image/webp";
            case "mp3" -> "audio/mpeg";
            case "m4a" -> "audio/mp4";
            case "aac" -> "audio/aac";
            case "wav" -> "audio/wav";
            case "ogg" -> "audio/ogg";
            case "webm" -> "audio/webm";
            case "pdf" -> "application/pdf";
            case "doc" -> "application/msword";
            case "docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
            case "xls" -> "application/vnd.ms-excel";
            case "xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
            case "txt" -> "text/plain";
            default -> "application/octet-stream";
        };
    }

    static String resolveKind(String mime, String filename) {
        String m = mime == null ? "" : mime.toLowerCase(Locale.ROOT);
        if (m.startsWith("image/")) {
            return "image";
        }
        if (m.startsWith("audio/")) {
            return "audio";
        }
        String ext = extensionOnly(filename);
        if (IMAGE_EXT.contains(ext)) {
            return "image";
        }
        if (AUDIO_EXT.contains(ext)) {
            return "audio";
        }
        if (DOC_EXT.contains(ext)) {
            return "document";
        }
        if (m.startsWith("text/") || m.contains("pdf") || m.contains("word") || m.contains("excel")
            || m.contains("powerpoint") || m.contains("officedocument")) {
            return "document";
        }
        throw new IllegalArgumentException("Type de fichier non pris en charge (image, audio ou document uniquement).");
    }

    private static String extensionOnly(String filename) {
        if (filename == null) {
            return "";
        }
        int dot = filename.lastIndexOf('.');
        if (dot < 0 || dot == filename.length() - 1) {
            return "";
        }
        return filename.substring(dot + 1).toLowerCase(Locale.ROOT);
    }

    private static String extensionOf(String filename, String kind, String mime) {
        String ext = extensionOnly(filename);
        if (!ext.isBlank()) {
            return "." + ext;
        }
        return switch (kind) {
            case "image" -> ".jpg";
            case "audio" -> ".m4a";
            default -> switch (mime) {
                case "application/pdf" -> ".pdf";
                case "text/plain" -> ".txt";
                default -> ".bin";
            };
        };
    }
}
