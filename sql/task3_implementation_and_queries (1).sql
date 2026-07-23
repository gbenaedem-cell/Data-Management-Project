-- ================================================================
-- OULAD TASK 3: RELATIONAL DATABASE IMPLEMENTATION AND QUERIES
-- Platform: MySQL 8.4 / MySQL Workbench
-- Target schema: oulad_db
--
-- IMPORTANT
-- 1. Do not execute this file while studentVle.csv is still importing.
-- 2. The script never drops or changes staging rows; Section 5 may add one
--    supporting index to stg_student_vle when that index is absent.
-- 3. Execute the numbered sections separately and inspect each result.
-- 4. Section 1 stops the script if any staging row count is incomplete.
-- ================================================================

USE oulad_db;


-- ================================================================
-- SECTION 1. PRE-FLIGHT: CONFIRM ALL SEVEN STAGING TABLES ARE READY
-- Expected row counts come from the source files and Task 1 profiling.
-- ================================================================

SELECT 'stg_courses' AS staging_table, COUNT(*) AS actual_rows, 22 AS expected_rows
FROM stg_courses
UNION ALL
SELECT 'stg_assessments', COUNT(*), 206 FROM stg_assessments
UNION ALL
SELECT 'stg_vle', COUNT(*), 6364 FROM stg_vle
UNION ALL
SELECT 'stg_student_info', COUNT(*), 32593 FROM stg_student_info
UNION ALL
SELECT 'stg_student_registration', COUNT(*), 32593 FROM stg_student_registration
UNION ALL
SELECT 'stg_student_assessment', COUNT(*), 173912 FROM stg_student_assessment
UNION ALL
SELECT 'stg_student_vle', COUNT(*), 10655280 FROM stg_student_vle;

DROP PROCEDURE IF EXISTS assert_oulad_staging_ready;
DELIMITER //
CREATE PROCEDURE assert_oulad_staging_ready()
BEGIN
    IF (SELECT COUNT(*) FROM stg_courses) <> 22 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'STOP: stg_courses row count is incomplete';
    END IF;
    IF (SELECT COUNT(*) FROM stg_assessments) <> 206 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'STOP: stg_assessments row count is incomplete';
    END IF;
    IF (SELECT COUNT(*) FROM stg_vle) <> 6364 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'STOP: stg_vle row count is incomplete';
    END IF;
    IF (SELECT COUNT(*) FROM stg_student_info) <> 32593 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'STOP: stg_student_info row count is incomplete';
    END IF;
    IF (SELECT COUNT(*) FROM stg_student_registration) <> 32593 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'STOP: stg_student_registration row count is incomplete';
    END IF;
    IF (SELECT COUNT(*) FROM stg_student_assessment) <> 173912 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'STOP: stg_student_assessment row count is incomplete';
    END IF;
    IF (SELECT COUNT(*) FROM stg_student_vle) <> 10655280 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'STOP: stg_student_vle row count is incomplete';
    END IF;
END//
DELIMITER ;

CALL assert_oulad_staging_ready();
DROP PROCEDURE assert_oulad_staging_ready;


-- ================================================================
-- SECTION 2. CREATE THE CLEAN RELATIONAL TABLES
-- Only final tables are replaced. Staging tables remain untouched.
-- ================================================================

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS student_vle_interaction;
DROP TABLE IF EXISTS student_assessment;
DROP TABLE IF EXISTS registration;
DROP TABLE IF EXISTS vle_resource;
DROP TABLE IF EXISTS assessment;
DROP TABLE IF EXISTS student;
DROP TABLE IF EXISTS module_presentation;

SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE module_presentation (
    code_module VARCHAR(5) NOT NULL,
    code_presentation VARCHAR(5) NOT NULL,
    module_presentation_length INT NOT NULL,
    CONSTRAINT pk_module_presentation
        PRIMARY KEY (code_module, code_presentation),
    CONSTRAINT chk_module_presentation_length
        CHECK (module_presentation_length > 0)
) ENGINE = InnoDB;

CREATE TABLE student (
    id_student INT NOT NULL,
    gender CHAR(1) NOT NULL,
    region VARCHAR(50) NOT NULL,
    highest_education VARCHAR(40) NOT NULL,
    imd_band VARCHAR(10) NULL,
    disability CHAR(1) NOT NULL,
    CONSTRAINT pk_student PRIMARY KEY (id_student),
    CONSTRAINT chk_student_gender CHECK (gender IN ('M', 'F')),
    CONSTRAINT chk_student_disability CHECK (disability IN ('Y', 'N')),
    CONSTRAINT chk_student_imd_band CHECK (
        imd_band IS NULL OR imd_band IN (
            '0-10%', '10-20%', '20-30%', '30-40%', '40-50%',
            '50-60%', '60-70%', '70-80%', '80-90%', '90-100%'
        )
    )
) ENGINE = InnoDB;

CREATE TABLE registration (
    id_student INT NOT NULL,
    code_module VARCHAR(5) NOT NULL,
    code_presentation VARCHAR(5) NOT NULL,
    age_band VARCHAR(10) NOT NULL,
    date_registration INT NULL,
    date_unregistration INT NULL,
    num_of_prev_attempts INT NOT NULL DEFAULT 0,
    studied_credits INT NOT NULL,
    final_result VARCHAR(20) NOT NULL,
    CONSTRAINT pk_registration
        PRIMARY KEY (id_student, code_module, code_presentation),
    CONSTRAINT fk_registration_student
        FOREIGN KEY (id_student)
        REFERENCES student (id_student),
    CONSTRAINT fk_registration_presentation
        FOREIGN KEY (code_module, code_presentation)
        REFERENCES module_presentation (code_module, code_presentation),
    CONSTRAINT chk_registration_age_band
        CHECK (age_band IN ('0-35', '35-55', '55<=')),
    CONSTRAINT chk_registration_attempts
        CHECK (num_of_prev_attempts >= 0),
    CONSTRAINT chk_registration_credits
        CHECK (studied_credits > 0),
    CONSTRAINT chk_registration_result
        CHECK (final_result IN ('Distinction', 'Pass', 'Fail', 'Withdrawn')),
    CONSTRAINT chk_registration_date_order CHECK (
        date_registration IS NULL
        OR date_unregistration IS NULL
        OR date_unregistration >= date_registration
    )
) ENGINE = InnoDB;

CREATE TABLE assessment (
    id_assessment INT NOT NULL,
    code_module VARCHAR(5) NOT NULL,
    code_presentation VARCHAR(5) NOT NULL,
    assessment_type VARCHAR(10) NOT NULL,
    assessment_date INT NULL,
    weight DECIMAL(5,2) NOT NULL,
    CONSTRAINT pk_assessment PRIMARY KEY (id_assessment),
    CONSTRAINT uq_assessment_context
        UNIQUE (id_assessment, code_module, code_presentation),
    CONSTRAINT fk_assessment_presentation
        FOREIGN KEY (code_module, code_presentation)
        REFERENCES module_presentation (code_module, code_presentation),
    CONSTRAINT chk_assessment_type
        CHECK (assessment_type IN ('TMA', 'CMA', 'Exam')),
    CONSTRAINT chk_assessment_weight
        CHECK (weight BETWEEN 0 AND 100)
) ENGINE = InnoDB;

CREATE TABLE vle_resource (
    id_site INT NOT NULL,
    code_module VARCHAR(5) NOT NULL,
    code_presentation VARCHAR(5) NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    week_from INT NULL,
    week_to INT NULL,
    CONSTRAINT pk_vle_resource PRIMARY KEY (id_site),
    CONSTRAINT uq_vle_resource_context
        UNIQUE (id_site, code_module, code_presentation),
    CONSTRAINT fk_vle_resource_presentation
        FOREIGN KEY (code_module, code_presentation)
        REFERENCES module_presentation (code_module, code_presentation),
    CONSTRAINT chk_vle_resource_weeks CHECK (
        (week_from IS NULL AND week_to IS NULL)
        OR
        (
            week_from IS NOT NULL
            AND week_to IS NOT NULL
            AND week_from >= 0
            AND week_to >= week_from
        )
    )
) ENGINE = InnoDB;

CREATE TABLE student_assessment (
    id_assessment INT NOT NULL,
    id_student INT NOT NULL,
    code_module VARCHAR(5) NOT NULL,
    code_presentation VARCHAR(5) NOT NULL,
    date_submitted INT NOT NULL,
    is_banked TINYINT NOT NULL DEFAULT 0,
    score INT NULL,
    CONSTRAINT pk_student_assessment
        PRIMARY KEY (id_assessment, id_student),
    CONSTRAINT fk_student_assessment_assessment
        FOREIGN KEY (id_assessment, code_module, code_presentation)
        REFERENCES assessment (id_assessment, code_module, code_presentation),
    CONSTRAINT fk_student_assessment_registration
        FOREIGN KEY (id_student, code_module, code_presentation)
        REFERENCES registration (id_student, code_module, code_presentation),
    CONSTRAINT chk_student_assessment_banked
        CHECK (is_banked IN (0, 1)),
    CONSTRAINT chk_student_assessment_score
        CHECK (score IS NULL OR score BETWEEN 0 AND 100),
    INDEX idx_student_assessment_student
        (id_student, code_module, code_presentation)
) ENGINE = InnoDB;

-- The large interaction table is intentionally created without indexes first.
-- Its composite primary key and foreign keys are added after set-based loading
-- and validation, which is faster for more than ten million rows.
CREATE TABLE student_vle_interaction (
    code_module VARCHAR(5) NOT NULL,
    code_presentation VARCHAR(5) NOT NULL,
    id_student INT NOT NULL,
    id_site INT NOT NULL,
    interaction_date INT NOT NULL,
    sum_click INT NOT NULL
) ENGINE = InnoDB;


-- ================================================================
-- SECTION 3. TRANSFORM AND LOAD THE SIX SMALLER RELATIONS
-- '?' and blank strings become NULL where the target allows missingness.
-- The inconsistent IMD label '10-20' becomes '10-20%'.
-- ================================================================

INSERT INTO module_presentation (
    code_module,
    code_presentation,
    module_presentation_length
)
SELECT
    TRIM(code_module),
    TRIM(code_presentation),
    CAST(TRIM(module_presentation_length) AS UNSIGNED)
FROM stg_courses;

INSERT INTO student (
    id_student,
    gender,
    region,
    highest_education,
    imd_band,
    disability
)
SELECT
    CAST(TRIM(id_student) AS UNSIGNED),
    MAX(TRIM(gender)),
    MAX(TRIM(region)),
    MAX(TRIM(highest_education)),
    MAX(
        CASE
            WHEN TRIM(imd_band) IN ('', '?') THEN NULL
            WHEN TRIM(imd_band) = '10-20' THEN '10-20%'
            ELSE TRIM(imd_band)
        END
    ),
    MAX(TRIM(disability))
FROM stg_student_info
GROUP BY CAST(TRIM(id_student) AS UNSIGNED);

INSERT INTO registration (
    id_student,
    code_module,
    code_presentation,
    age_band,
    date_registration,
    date_unregistration,
    num_of_prev_attempts,
    studied_credits,
    final_result
)
SELECT
    CAST(TRIM(si.id_student) AS UNSIGNED),
    TRIM(si.code_module),
    TRIM(si.code_presentation),
    TRIM(si.age_band),
    CAST(NULLIF(NULLIF(TRIM(sr.date_registration), '?'), '') AS SIGNED),
    CAST(NULLIF(NULLIF(TRIM(sr.date_unregistration), '?'), '') AS SIGNED),
    CAST(TRIM(si.num_of_prev_attempts) AS UNSIGNED),
    CAST(TRIM(si.studied_credits) AS UNSIGNED),
    TRIM(si.final_result)
FROM stg_student_info AS si
JOIN stg_student_registration AS sr
  ON TRIM(sr.code_module) = TRIM(si.code_module)
 AND TRIM(sr.code_presentation) = TRIM(si.code_presentation)
 AND CAST(TRIM(sr.id_student) AS UNSIGNED) = CAST(TRIM(si.id_student) AS UNSIGNED);

INSERT INTO assessment (
    id_assessment,
    code_module,
    code_presentation,
    assessment_type,
    assessment_date,
    weight
)
SELECT
    CAST(TRIM(id_assessment) AS UNSIGNED),
    TRIM(code_module),
    TRIM(code_presentation),
    TRIM(assessment_type),
    CAST(NULLIF(NULLIF(TRIM(`date`), '?'), '') AS SIGNED),
    CAST(TRIM(weight) AS DECIMAL(5,2))
FROM stg_assessments;

INSERT INTO vle_resource (
    id_site,
    code_module,
    code_presentation,
    activity_type,
    week_from,
    week_to
)
SELECT
    CAST(TRIM(id_site) AS UNSIGNED),
    TRIM(code_module),
    TRIM(code_presentation),
    TRIM(activity_type),
    CAST(NULLIF(NULLIF(TRIM(week_from), '?'), '') AS SIGNED),
    CAST(NULLIF(NULLIF(TRIM(week_to), '?'), '') AS SIGNED)
FROM stg_vle;

INSERT INTO student_assessment (
    id_assessment,
    id_student,
    code_module,
    code_presentation,
    date_submitted,
    is_banked,
    score
)
SELECT
    CAST(TRIM(sa.id_assessment) AS UNSIGNED),
    CAST(TRIM(sa.id_student) AS UNSIGNED),
    a.code_module,
    a.code_presentation,
    CAST(TRIM(sa.date_submitted) AS SIGNED),
    CAST(TRIM(sa.is_banked) AS UNSIGNED),
    CAST(NULLIF(NULLIF(TRIM(sa.score), '?'), '') AS SIGNED)
FROM stg_student_assessment AS sa
JOIN assessment AS a
  ON a.id_assessment = CAST(TRIM(sa.id_assessment) AS UNSIGNED);


-- ================================================================
-- SECTION 4. VERIFY THE SIX SMALLER RELATIONS BEFORE THE LARGE LOAD
-- Every actual_rows value must match expected_rows.
-- ================================================================

SELECT 'module_presentation' AS final_table, COUNT(*) AS actual_rows, 22 AS expected_rows
FROM module_presentation
UNION ALL
SELECT 'student', COUNT(*), 28785 FROM student
UNION ALL
SELECT 'registration', COUNT(*), 32593 FROM registration
UNION ALL
SELECT 'assessment', COUNT(*), 206 FROM assessment
UNION ALL
SELECT 'vle_resource', COUNT(*), 6364 FROM vle_resource
UNION ALL
SELECT 'student_assessment', COUNT(*), 173912 FROM student_assessment;


-- ================================================================
-- SECTION 5. LOAD THE LARGE studentVle RELATION
-- The raw file contains repeated student-resource-day keys. At the documented
-- daily-summary grain, duplicate rows are consolidated with SUM(sum_click).
-- Run this section only after the staging import and Task 1 checks are complete.
-- ================================================================

-- Create the profiling/load index once when Task 1 has not already created it.
SET @stg_vle_index_exists = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = 'oulad_db'
      AND table_name = 'stg_student_vle'
      AND index_name = 'idx_stg_vle_duplicate_check'
);
SET @stg_vle_index_sql = IF(
    @stg_vle_index_exists = 0,
    'ALTER TABLE stg_student_vle ADD INDEX idx_stg_vle_duplicate_check (code_module, code_presentation, id_student, id_site, `date`)',
    'DO 0'
);
PREPARE stg_vle_index_stmt FROM @stg_vle_index_sql;
EXECUTE stg_vle_index_stmt;
DEALLOCATE PREPARE stg_vle_index_stmt;

-- Make this section safely repeatable without appending another copy.
TRUNCATE TABLE student_vle_interaction;

INSERT INTO student_vle_interaction (
    code_module,
    code_presentation,
    id_student,
    id_site,
    interaction_date,
    sum_click
)
SELECT
    TRIM(sv.code_module),
    TRIM(sv.code_presentation),
    CAST(TRIM(sv.id_student) AS UNSIGNED),
    CAST(TRIM(sv.id_site) AS UNSIGNED),
    CAST(TRIM(sv.`date`) AS SIGNED),
    SUM(CAST(TRIM(sv.sum_click) AS UNSIGNED))
FROM stg_student_vle AS sv
FORCE INDEX (idx_stg_vle_duplicate_check)
GROUP BY
    sv.code_module,
    sv.code_presentation,
    sv.id_student,
    sv.id_site,
    sv.`date`;

SELECT
    COUNT(*) AS cleaned_student_vle_rows,
    8459320 AS expected_cleaned_rows,
    10655280 - COUNT(*) AS duplicate_rows_consolidated
FROM student_vle_interaction;


-- ================================================================
-- SECTION 6. VALIDATE THE LARGE RELATION BEFORE ADDING CONSTRAINTS
-- The grouped load guarantees one record at the intended daily grain.
-- The following checks must return zero problem records.
-- ================================================================

SELECT
    COUNT(*) AS cleaned_rows,
    10655280 - COUNT(*) AS duplicate_rows_consolidated,
    MIN(interaction_date) AS earliest_interaction_day,
    MAX(interaction_date) AS latest_interaction_day,
    MIN(sum_click) AS minimum_sum_click,
    MAX(sum_click) AS maximum_sum_click,
    SUM(sum_click <= 0) AS nonpositive_click_rows
FROM student_vle_interaction
;

-- A value of 0 means every interaction matches a registration.
SELECT EXISTS (
    SELECT 1
    FROM student_vle_interaction AS svi
    LEFT JOIN registration AS r
      ON r.id_student = svi.id_student
     AND r.code_module = svi.code_module
     AND r.code_presentation = svi.code_presentation
    WHERE r.id_student IS NULL
    LIMIT 1
) AS has_interaction_without_registration;

-- A value of 0 means every interaction matches its contextual VLE resource.
SELECT EXISTS (
    SELECT 1
    FROM student_vle_interaction AS svi
    LEFT JOIN vle_resource AS vr
      ON vr.id_site = svi.id_site
     AND vr.code_module = svi.code_module
     AND vr.code_presentation = svi.code_presentation
    WHERE vr.id_site IS NULL
    LIMIT 1
) AS has_interaction_without_matching_resource;


-- ================================================================
-- SECTION 7. ADD THE LARGE-TABLE PRIMARY KEY, INDEXES AND FOREIGN KEYS
-- Execute only if every Section 6 validation has passed.
-- Building these indexes over 8.46 million cleaned rows can take considerable time.
-- ================================================================

ALTER TABLE student_vle_interaction
    ADD CONSTRAINT pk_student_vle_interaction
        PRIMARY KEY (
            code_module,
            code_presentation,
            id_student,
            id_site,
            interaction_date
        ),
    ADD INDEX idx_student_vle_registration
        (id_student, code_module, code_presentation),
    ADD INDEX idx_student_vle_resource
        (id_site, code_module, code_presentation),
    ADD CONSTRAINT fk_student_vle_registration
        FOREIGN KEY (id_student, code_module, code_presentation)
        REFERENCES registration (id_student, code_module, code_presentation),
    ADD CONSTRAINT fk_student_vle_resource
        FOREIGN KEY (id_site, code_module, code_presentation)
        REFERENCES vle_resource (id_site, code_module, code_presentation);

ANALYZE TABLE
    module_presentation,
    student,
    registration,
    assessment,
    vle_resource,
    student_assessment,
    student_vle_interaction;


-- ================================================================
-- SECTION 8. FINAL IMPLEMENTATION EVIDENCE
-- Capture screenshots of these results for the Task 3 report.
-- ================================================================

SHOW TABLES;

SELECT 'module_presentation' AS final_table, COUNT(*) AS total_rows
FROM module_presentation
UNION ALL
SELECT 'student', COUNT(*) FROM student
UNION ALL
SELECT 'registration', COUNT(*) FROM registration
UNION ALL
SELECT 'assessment', COUNT(*) FROM assessment
UNION ALL
SELECT 'vle_resource', COUNT(*) FROM vle_resource
UNION ALL
SELECT 'student_assessment', COUNT(*) FROM student_assessment
UNION ALL
SELECT 'student_vle_interaction', COUNT(*) FROM student_vle_interaction;

SELECT
    table_name,
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'oulad_db'
  AND table_name IN (
      'module_presentation',
      'student',
      'registration',
      'assessment',
      'vle_resource',
      'student_assessment',
      'student_vle_interaction'
  )
ORDER BY table_name, constraint_type, constraint_name;


-- ================================================================
-- SECTION 9. PRACTICAL LEARNING-ANALYTICS QUERIES
-- ================================================================

-- QUESTION 1
-- Which module presentations have the strongest completion outcomes?
SELECT
    code_module,
    code_presentation,
    COUNT(*) AS registered_students,
    SUM(final_result = 'Distinction') AS distinctions,
    SUM(final_result = 'Pass') AS passes,
    SUM(final_result = 'Fail') AS failures,
    SUM(final_result = 'Withdrawn') AS withdrawals,
    ROUND(
        100.0 * SUM(final_result IN ('Pass', 'Distinction')) / COUNT(*),
        2
    ) AS successful_completion_rate_pct
FROM registration
GROUP BY code_module, code_presentation
ORDER BY successful_completion_rate_pct DESC, registered_students DESC;


-- QUESTION 2
-- How do submission volume and scores differ by module and assessment type?
SELECT
    a.code_module,
    a.code_presentation,
    a.assessment_type,
    COUNT(sa.id_student) AS submissions,
    SUM(
    CASE
        WHEN sa.id_student IS NOT NULL AND sa.score IS NULL THEN 1
        ELSE 0
    END
) AS missing_scores,
    ROUND(AVG(sa.score), 2) AS average_score,
    ROUND(100.0 * AVG(sa.is_banked), 2) AS banked_result_rate_pct
FROM assessment AS a
LEFT JOIN student_assessment AS sa
  ON sa.id_assessment = a.id_assessment
GROUP BY
    a.code_module,
    a.code_presentation,
    a.assessment_type
ORDER BY a.code_module, a.code_presentation, a.assessment_type;


-- QUESTION 3
-- How does VLE engagement differ across final-result groups?
WITH engagement_by_registration AS (
    SELECT
        code_module,
        code_presentation,
        id_student,
        SUM(sum_click) AS total_clicks,
        COUNT(DISTINCT interaction_date) AS active_days,
        COUNT(DISTINCT id_site) AS resources_used
    FROM student_vle_interaction
    GROUP BY code_module, code_presentation, id_student
)
SELECT
    r.final_result,
    COUNT(*) AS registrations,
    ROUND(AVG(COALESCE(e.total_clicks, 0)), 2) AS average_total_clicks,
    ROUND(AVG(COALESCE(e.active_days, 0)), 2) AS average_active_days,
    ROUND(AVG(COALESCE(e.resources_used, 0)), 2) AS average_resources_used
FROM registration AS r
LEFT JOIN engagement_by_registration AS e
  ON e.id_student = r.id_student
 AND e.code_module = r.code_module
 AND e.code_presentation = r.code_presentation
GROUP BY r.final_result
ORDER BY average_total_clicks DESC;
