package com.payflex.backend.dto;

import java.util.List;

public record AdminDashboardResponse(
    Metrics metrics,
    List<PaymentPoint> weeklyPayments,
    List<AgentPerformance> topAgents,
    List<UserSummary> recentUsers,
    List<ProductSummary> products
) {
    public record Metrics(
        long totalUsers,
        long activeAgents,
        long totalClients,
        long totalProducts,
        double totalCollected,
        long pendingContributions,
        long pendingRegistrations
    ) {}

    public record PaymentPoint(String day, double amount) {}

    public record AgentPerformance(
        String agentName,
        long clientsCount,
        double collectedAmount,
        double objectivePercent
    ) {}

    public record UserSummary(
        Long id,
        String fullName,
        String role,
        String city,
        String status
    ) {}

    public record ProductSummary(
        String code,
        String name,
        String category,
        double price,
        String availability
    ) {}
}
