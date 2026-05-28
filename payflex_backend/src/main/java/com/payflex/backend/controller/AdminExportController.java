package com.payflex.backend.controller;

import com.payflex.backend.service.AdminAuditService;
import com.payflex.backend.service.AdminCrudService;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.font.Standard14Fonts;
import org.apache.pdfbox.pdmodel.font.PDType1Font;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.List;

@RestController
@RequestMapping("/admin/export")
public class AdminExportController {

    private final AdminCrudService crudService;
    private final AdminAuditService auditService;

    public AdminExportController(AdminCrudService crudService, AdminAuditService auditService) {
        this.crudService = crudService;
        this.auditService = auditService;
    }

    @GetMapping("/{entity}.csv")
    public ResponseEntity<byte[]> exportCsv(@PathVariable String entity) {
        String csv = switch (entity) {
            case "users" -> usersCsv();
            case "products" -> productsCsv();
            case "agents" -> agentsCsv();
            case "contributions" -> contributionsCsv();
            case "audit" -> auditCsv();
            default -> "unsupported";
        };
        byte[] body = csv.getBytes(StandardCharsets.UTF_8);
        return ResponseEntity.ok()
            .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + entity + ".csv\"")
            .contentType(new MediaType("text", "csv"))
            .body(body);
    }

    @GetMapping("/{entity}.pdf")
    public ResponseEntity<byte[]> exportPdf(@PathVariable String entity) throws Exception {
        List<String> lines = switch (entity) {
            case "users" -> crudService.getUsers().stream().map(u -> u.id() + " | " + u.fullName() + " | " + u.phone() + " | " + u.role() + " | " + u.status()).toList();
            case "products" -> crudService.getProducts().stream().map(p -> p.code() + " | " + p.name() + " | " + p.category() + " | " + p.price() + " | minJ=" + p.minDailyContribution() + " | vedette=" + p.featured()).toList();
            case "agents" -> crudService.getAgents().stream().map(a -> a.id() + " | " + a.fullName() + " | " + a.zone() + " | " + a.collectedTotal()).toList();
            case "contributions" -> crudService.getContributions().stream().map(c -> c.id() + " | " + c.userName() + " | " + c.amount() + " | " + c.status()).toList();
            case "audit" -> auditService.latest(500).stream().map(a ->
                a.createdAt() + " | " + a.profileLabel() + " | " + a.actorDisplay() + " | " + a.message()).toList();
            default -> List.of("Export non supporte");
        };

        String titrePdf = "audit".equals(entity) ? "Journal d'activité PayFlex" : "Export " + entity;
        byte[] pdf = createSimplePdf(titrePdf, lines);
        return ResponseEntity.ok()
            .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + entity + ".pdf\"")
            .contentType(MediaType.APPLICATION_PDF)
            .body(pdf);
    }

    /**
     * Version "impression" du journal: ouverture inline dans le navigateur.
     */
    @GetMapping("/audit-print.pdf")
    public ResponseEntity<byte[]> printAuditPdf() throws Exception {
        List<String> lines = auditService.latest(500).stream().map(a ->
            a.createdAt() + " | " + a.profileLabel() + " | " + a.actorDisplay() + " | " + a.message()).toList();
        byte[] pdf = createSimplePdf("Journal d'activite PayFlex", lines);
        return ResponseEntity.ok()
            .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"audit-print.pdf\"")
            .contentType(MediaType.APPLICATION_PDF)
            .body(pdf);
    }

    private byte[] createSimplePdf(String title, List<String> lines) throws Exception {
        try (PDDocument document = new PDDocument()) {
            PDPage page = new PDPage(PDRectangle.A4);
            document.addPage(page);
            PDType1Font font = new PDType1Font(Standard14Fonts.FontName.HELVETICA);
            float y = 800;
            PDPageContentStream cs = new PDPageContentStream(document, page);
            cs.setFont(font, 12);
            cs.beginText();
            cs.newLineAtOffset(40, y);
            cs.showText(title);
            cs.endText();
            y -= 24;

            for (String line : lines) {
                if (y < 50) {
                    cs.close();
                    page = new PDPage(PDRectangle.A4);
                    document.addPage(page);
                    cs = new PDPageContentStream(document, page);
                    cs.setFont(font, 10);
                    y = 800;
                }
                cs.beginText();
                cs.setFont(font, 10);
                cs.newLineAtOffset(40, y);
                cs.showText(line.length() > 115 ? line.substring(0, 115) : line);
                cs.endText();
                y -= 14;
            }
            cs.close();
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            document.save(out);
            return out.toByteArray();
        }
    }

    private String usersCsv() {
        StringBuilder sb = new StringBuilder("id,full_name,phone,role,city,profession,status\n");
        crudService.getUsers().forEach(u -> sb.append(u.id()).append(',').append(esc(u.fullName())).append(',').append(esc(u.phone())).append(',').append(esc(u.role())).append(',').append(esc(u.city())).append(',').append(esc(u.profession())).append(',').append(esc(u.status())).append('\n'));
        return sb.toString();
    }

    private String productsCsv() {
        StringBuilder sb = new StringBuilder("id,code,name,category,price,min_daily_contribution,availability,featured\n");
        crudService.getProducts().forEach(p -> sb.append(p.id()).append(',').append(esc(p.code())).append(',').append(esc(p.name())).append(',').append(esc(p.category())).append(',').append(p.price()).append(',').append(p.minDailyContribution()).append(',').append(esc(p.availability())).append(',').append(p.featured()).append('\n'));
        return sb.toString();
    }

    private String agentsCsv() {
        StringBuilder sb = new StringBuilder("id,full_name,city,zone,active,terrain_objective_auto\n");
        crudService.getAgents().forEach(a -> sb.append(a.id()).append(',').append(esc(a.fullName())).append(',').append(esc(a.city())).append(',').append(esc(a.zone())).append(',').append(a.active()).append(',').append(a.collectedTotal()).append('\n'));
        return sb.toString();
    }

    private String contributionsCsv() {
        StringBuilder sb = new StringBuilder("id,user_name,product_name,agent_name,amount,payment_mode,status,reference_code\n");
        crudService.getContributions().forEach(c -> sb.append(c.id()).append(',').append(esc(c.userName())).append(',').append(esc(c.productName())).append(',').append(esc(c.agentName())).append(',').append(c.amount()).append(',').append(esc(c.paymentMode())).append(',').append(esc(c.status())).append(',').append(esc(c.referenceCode())).append('\n'));
        return sb.toString();
    }

    private String auditCsv() {
        StringBuilder sb = new StringBuilder("date,origine,qui,evenement\n");
        auditService.latest(500).forEach(a -> sb.append(esc(a.createdAt())).append(',').append(esc(a.profileLabel())).append(',').append(esc(a.actorDisplay())).append(',').append(esc(a.message())).append('\n'));
        return sb.toString();
    }

    private String esc(String v) {
        if (v == null) return "";
        String cleaned = v.replace("\"", "\"\"");
        return "\"" + cleaned + "\"";
    }
}
