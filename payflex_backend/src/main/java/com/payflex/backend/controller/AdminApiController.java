package com.payflex.backend.controller;

import com.payflex.backend.dto.AdminDashboardResponse;
import com.payflex.backend.service.AdminDashboardService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin")
public class AdminApiController {

    private final AdminDashboardService dashboardService;

    public AdminApiController(AdminDashboardService dashboardService) {
        this.dashboardService = dashboardService;
    }

    @GetMapping("/dashboard")
    public AdminDashboardResponse dashboard() {
        return dashboardService.buildDashboard();
    }
}
