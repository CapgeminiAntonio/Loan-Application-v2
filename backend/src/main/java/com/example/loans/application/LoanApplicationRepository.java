package com.example.loans.application;

import com.example.loans.application.model.ApplicationRow;
import com.example.loans.application.model.Decision;
import com.example.loans.application.model.DecisionOutcome;
import com.example.loans.application.model.OfficerDetailRow;
import com.example.loans.application.model.QueueRow;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Repository
public class LoanApplicationRepository {
    private final NamedParameterJdbcTemplate jdbc;

    public LoanApplicationRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<ApplicationRow> findByCustomer(long customerId) {
        String sql = """
            SELECT id, reference, amount, term_months, purpose, employment_status,
                   monthly_income, status, submitted_at, decision_note, decided_at, decided_by
            FROM loan_applications
            WHERE customer_id = :customerId
            ORDER BY submitted_at DESC, id DESC
            """;
        return jdbc.query(sql, new MapSqlParameterSource("customerId", customerId),
                (rs, rowNum) -> new ApplicationRow(
                        rs.getLong("id"), rs.getString("reference"), rs.getBigDecimal("amount"),
                        rs.getInt("term_months"), rs.getString("purpose"), rs.getString("employment_status"),
                        rs.getBigDecimal("monthly_income"), rs.getString("status"),
                        rs.getTimestamp("submitted_at").toInstant(), rs.getString("decision_note"),
                        rs.getTimestamp("decided_at") == null ? null : rs.getTimestamp("decided_at").toInstant(),
                        rs.getObject("decided_by") == null ? null : rs.getLong("decided_by")));
    }

    public Optional<ApplicationRow> findByIdAndCustomer(long id, long customerId) {
        String sql = """
            SELECT id, reference, amount, term_months, purpose, employment_status,
                   monthly_income, status, submitted_at, decision_note, decided_at, decided_by
            FROM loan_applications
            WHERE id = :id AND customer_id = :customerId
            """;
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("id", id).addValue("customerId", customerId);
        return jdbc.query(sql, params, (rs, rowNum) -> new ApplicationRow(
                        rs.getLong("id"), rs.getString("reference"), rs.getBigDecimal("amount"),
                        rs.getInt("term_months"), rs.getString("purpose"), rs.getString("employment_status"),
                        rs.getBigDecimal("monthly_income"), rs.getString("status"),
                        rs.getTimestamp("submitted_at").toInstant(), rs.getString("decision_note"),
                        rs.getTimestamp("decided_at") == null ? null : rs.getTimestamp("decided_at").toInstant(),
                        rs.getObject("decided_by") == null ? null : rs.getLong("decided_by")))
                .stream().findFirst();
    }

    public List<QueueRow> findPendingQueue() {
        String sql = """
            SELECT la.id, la.reference, u.full_name AS applicant_name, la.amount,
                   la.term_months, la.purpose, la.submitted_at
            FROM loan_applications la
            JOIN users u ON u.id = la.customer_id
            WHERE la.status = 'SUBMITTED'
            ORDER BY la.submitted_at ASC, la.id ASC
            """;
        return jdbc.query(sql, (rs, rowNum) -> new QueueRow(
                rs.getLong("id"), rs.getString("reference"), rs.getString("applicant_name"),
                rs.getBigDecimal("amount"), rs.getInt("term_months"), rs.getString("purpose"),
                rs.getTimestamp("submitted_at").toInstant()));
    }

    public Optional<OfficerDetailRow> findDetailForOfficer(long id) {
        String sql = """
            SELECT la.id, la.reference, la.amount, la.term_months, la.purpose,
                   la.employment_status, la.monthly_income, la.status, la.submitted_at,
                   la.decision_note, la.decided_at,
                   applicant.id AS applicant_id, applicant.username AS applicant_username,
                   applicant.full_name AS applicant_full_name,
                   officer.id AS decided_by_id, officer.username AS decided_by_username,
                   officer.full_name AS decided_by_full_name
            FROM loan_applications la
            JOIN users applicant ON applicant.id = la.customer_id
            LEFT JOIN users officer ON officer.id = la.decided_by
            WHERE la.id = :id
            """;
        return jdbc.query(sql, new MapSqlParameterSource("id", id), (rs, rowNum) -> new OfficerDetailRow(
                        rs.getLong("id"), rs.getString("reference"), rs.getBigDecimal("amount"),
                        rs.getInt("term_months"), rs.getString("purpose"), rs.getString("employment_status"),
                        rs.getBigDecimal("monthly_income"), rs.getString("status"),
                        rs.getTimestamp("submitted_at").toInstant(), rs.getString("decision_note"),
                        rs.getTimestamp("decided_at") == null ? null : rs.getTimestamp("decided_at").toInstant(),
                        rs.getLong("applicant_id"), rs.getString("applicant_username"), rs.getString("applicant_full_name"),
                        rs.getObject("decided_by_id") == null ? null : rs.getLong("decided_by_id"),
                        rs.getString("decided_by_username"), rs.getString("decided_by_full_name")))
                .stream().findFirst();
    }

    public DecisionOutcome decide(long id, Decision status, String note, long officerId, Instant decidedAt) {
        String update = """
            UPDATE loan_applications
               SET status = :status,
                   decision_note = :note,
                   decided_by = :officerId,
                   decided_at = :now
             WHERE id = :id AND status = 'SUBMITTED'
            """;
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("status", status.name())
                .addValue("note", note)
                .addValue("officerId", officerId)
                .addValue("now", Timestamp.from(decidedAt))
                .addValue("id", id);
        int affected = jdbc.update(update, params);
        if (affected == 1) return DecisionOutcome.UPDATED;

        Boolean exists = jdbc.queryForObject(
                "SELECT EXISTS (SELECT 1 FROM loan_applications WHERE id = :id)",
                new MapSqlParameterSource("id", id), Boolean.class);
        return Boolean.TRUE.equals(exists)
                ? DecisionOutcome.ALREADY_DECIDED
                : DecisionOutcome.NOT_FOUND;
    }
}
