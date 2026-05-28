package com.payflex.backend.controller;

import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

import java.util.Map;

@ControllerAdvice
public class AdminExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(AdminExceptionHandler.class);

    @ExceptionHandler(IllegalArgumentException.class)
    public Object handleValidation(IllegalArgumentException ex, HttpServletRequest request) {
        if (isMobileApi(request)) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        }
        String referer = request.getHeader("Referer");
        if (referer == null || referer.isBlank()) {
            return "redirect:/admin?error=1";
        }
        return "redirect:" + referer + (referer.contains("?") ? "&" : "?") + "error=1";
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public Object handleIntegrity(DataIntegrityViolationException ex, HttpServletRequest request) {
        if (isMobileApi(request)) {
            return ResponseEntity.badRequest().body(Map.of(
                "message", "Donnée en conflit avec un enregistrement existant."
            ));
        }
        String referer = request.getHeader("Referer");
        if (referer == null || referer.isBlank()) {
            return "redirect:/admin?error=1";
        }
        return "redirect:" + referer + (referer.contains("?") ? "&" : "?") + "error=1";
    }

    @ExceptionHandler(IllegalStateException.class)
    public Object handleIllegalState(IllegalStateException ex, HttpServletRequest request) {
        if (isMobileApi(request)) {
            log.warn("API mobile : {}", ex.getMessage());
            return ResponseEntity.status(502).body(Map.of(
                "message", ex.getMessage() != null ? ex.getMessage() : "Service temporairement indisponible."
            ));
        }
        throw ex;
    }

    @ExceptionHandler(Exception.class)
    public Object handleUnexpected(Exception ex, HttpServletRequest request) throws Exception {
        if (isMobileApi(request)) {
            log.error("API mobile inattendue : {}", ex.getMessage(), ex);
            return ResponseEntity.internalServerError().body(Map.of(
                "message", "Le service est momentanément indisponible. Réessayez plus tard."
            ));
        }
        throw ex;
    }

    private static boolean isMobileApi(HttpServletRequest request) {
        String uri = request.getRequestURI();
        return uri != null && uri.startsWith("/api/mobile/");
    }
}
