package com.example.loans.application.model;

import java.math.BigDecimal;
import java.time.Instant;

public record ApplicationRow(
        long id,
        String reference,
        BigDecimal amount,
        int termMonths,
        String purpose,
        String employmentStatus,
        BigDecimal monthlyIncome,
        String status,
        Instant submittedAt,
        String decisionNote,
        Instant decidedAt,
        Long decidedById
) {}
