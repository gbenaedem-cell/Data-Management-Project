USE oulad_db;

-- =====================================================
-- QUERY 1 BASELINE: Completion outcomes by presentation
-- =====================================================

EXPLAIN ANALYZE
SELECT
    code_module,
    code_presentation,
    COUNT(*) AS registrations,
    SUM(final_result IN ('Pass', 'Distinction')) AS successful_students,
    ROUND(
        100.0 * SUM(final_result IN ('Pass', 'Distinction'))
        / COUNT(*),
        2
    ) AS success_rate
FROM registration
GROUP BY
    code_module,
    code_presentation;
    
    

EXPLAIN ANALYZE
SELECT
    code_module,
    code_presentation,
    COUNT(*) AS registrations,
    SUM(final_result IN ('Pass', 'Distinction')) AS successful_students,
    ROUND(
        100.0 * SUM(final_result IN ('Pass', 'Distinction'))
        / COUNT(*),
        2
    ) AS success_rate
FROM registration
GROUP BY
    code_module,
    code_presentation;
    
    -- =====================================================
-- QUERY 2 BASELINE: Assessment performance
-- =====================================================

EXPLAIN ANALYZE
SELECT
    a.code_module,
    a.code_presentation,
    a.assessment_type,
    COUNT(*) AS submissions,
    ROUND(AVG(sa.score), 2) AS average_score,
    SUM(
        CASE WHEN sa.score IS NULL THEN 1 ELSE 0 END
    ) AS missing_scores,
    ROUND(100.0 * AVG(sa.is_banked), 2) AS banked_rate
FROM assessment AS a
INNER JOIN student_assessment AS sa
    ON sa.id_assessment = a.id_assessment
GROUP BY
    a.code_module,
    a.code_presentation,
    a.assessment_type;
    
    -- =====================================================
-- QUERY 2: Create reporting indexes
-- =====================================================

CREATE INDEX idx_assessment_reporting
ON assessment (
    code_module,
    code_presentation,
    assessment_type,
    id_assessment
);

CREATE INDEX idx_student_assessment_metrics
ON student_assessment (
    id_assessment,
    score,
    is_banked
);

-- Refresh optimizer statistics
ANALYZE TABLE assessment, student_assessment;

-- =====================================================
-- QUERY 2: Create reporting indexes
-- =====================================================

CREATE INDEX idx_assessment_reporting
ON assessment (
    code_module,
    code_presentation,
    assessment_type,
    id_assessment
);

CREATE INDEX idx_student_assessment_metrics
ON student_assessment (
    id_assessment,
    score,
    is_banked
);

-- Refresh optimizer statistics
ANALYZE TABLE assessment, student_assessment;

EXPLAIN ANALYZE
SELECT
    a.code_module,
    a.code_presentation,
    a.assessment_type,
    COUNT(*) AS submissions,
    ROUND(AVG(sa.score), 2) AS average_score,
    SUM(
        CASE WHEN sa.score IS NULL THEN 1 ELSE 0 END
    ) AS missing_scores,
    ROUND(100.0 * AVG(sa.is_banked), 2) AS banked_rate
FROM assessment AS a
INNER JOIN student_assessment AS sa
    ON sa.id_assessment = a.id_assessment
GROUP BY
    a.code_module,
    a.code_presentation,
    a.assessment_type;
    
    -- =====================================================
-- QUERY 3 BASELINE: VLE resource availability
-- =====================================================

EXPLAIN ANALYZE
SELECT
    code_module,
    code_presentation,
    activity_type,
    COUNT(*) AS resources,
    SUM(
        week_from IS NULL OR week_to IS NULL
    ) AS resources_missing_week_information,
    MIN(week_from) AS earliest_week,
    MAX(week_to) AS latest_week
FROM vle_resource
GROUP BY
    code_module,
    code_presentation,
    activity_type;
    
    -- =====================================================
-- QUERY 3: Create reporting index
-- =====================================================

CREATE INDEX idx_vle_resource_reporting
ON vle_resource (
    code_module,
    code_presentation,
    activity_type,
    week_from,
    week_to
);

-- Refresh optimizer statistics
ANALYZE TABLE vle_resource;

EXPLAIN ANALYZE
SELECT
    code_module,
    code_presentation,
    activity_type,
    COUNT(*) AS resources,
    SUM(
        week_from IS NULL OR week_to IS NULL
    ) AS resources_missing_week_information,
    MIN(week_from) AS earliest_week,
    MAX(week_to) AS latest_week
FROM vle_resource
GROUP BY
    code_module,
    code_presentation,
    activity_type;
    
    -- =====================================================
-- FINAL INDEX CLEANUP
-- =====================================================

DROP INDEX idx_student_assessment_metrics
ON student_assessment;

ANALYZE TABLE student_assessment;

SELECT
    table_name,
    index_name,
    GROUP_CONCAT(
        column_name
        ORDER BY seq_in_index
        SEPARATOR ', '
    ) AS index_columns
FROM information_schema.statistics
WHERE table_schema = 'oulad_db'
  AND index_name IN (
      'idx_registration_outcome_cover',
      'idx_assessment_reporting',
      'idx_vle_resource_reporting'
  )
GROUP BY
    table_name,
    index_name
ORDER BY
    table_name,
    index_name;