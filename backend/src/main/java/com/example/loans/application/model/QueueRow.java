package com.example.loans.application.model;

import java.math.BigDecimal;
import java.time.Instant;

public record QueueRow(
        long id,
        String reference,
        String applicantName,
        BigDecimal amount,
        int termMonths,
        String purpose,
        Instant submittedAt
) {}
