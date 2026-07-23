-- =====================================================
-- TASK 7: OULAD STAR-SCHEMA DATA MART
-- SECTION 1: Verify Task 6 source tables
-- =====================================================

SELECT 'clean_student' AS source_table,
       COUNT(*) AS total_rows
FROM oulad_etl.clean_student

UNION ALL

SELECT 'clean_module_presentation',
       COUNT(*)
FROM oulad_etl.clean_module_presentation

UNION ALL

SELECT 'clean_registration',
       COUNT(*)
FROM oulad_etl.clean_registration

UNION ALL

SELECT 'analytics_student_engagement',
       COUNT(*)
FROM oulad_etl.analytics_student_engagement;

-- =====================================================
-- SECTION 2: Create the data-warehouse database
-- =====================================================



USE oulad_dw;

SELECT DATABASE() AS selected_database;


-- =====================================================
-- SECTION 3: Create and load the student dimension
-- =====================================================

USE oulad_dw;

DROP TABLE IF EXISTS dim_student;

CREATE TABLE dim_student (
    student_key INT NOT NULL AUTO_INCREMENT,
    id_student INT NOT NULL,
    gender CHAR(1) NOT NULL,
    region VARCHAR(50) NOT NULL,
    highest_education VARCHAR(40) NOT NULL,
    imd_band VARCHAR(10),
    disability CHAR(1) NOT NULL,

    CONSTRAINT pk_dim_student
        PRIMARY KEY (student_key),

    CONSTRAINT uq_dim_student_id
        UNIQUE (id_student),

    CONSTRAINT chk_dim_student_gender
        CHECK (gender IN ('M', 'F')),

    CONSTRAINT chk_dim_student_disability
        CHECK (disability IN ('Y', 'N'))
) ENGINE=InnoDB;

-- Load cleaned student records into the dimension

INSERT INTO dim_student (
    id_student,
    gender,
    region,
    highest_education,
    imd_band,
    disability
)
SELECT
    id_student,
    gender,
    region,
    highest_education,
    imd_band,
    disability
FROM oulad_etl.clean_student
ORDER BY id_student;

SELECT
    COUNT(*) AS dimension_rows,
    COUNT(DISTINCT student_key) AS unique_student_keys,
    COUNT(DISTINCT id_student) AS unique_source_students
FROM dim_student;

SELECT
    id_student,
    COUNT(*) AS number_of_records
FROM dim_student
GROUP BY id_student
HAVING COUNT(*) > 1;


-- =====================================================
-- SECTION 4: Create and load module-presentation dimension
-- =====================================================

USE oulad_dw;

DROP TABLE IF EXISTS dim_module_presentation;

CREATE TABLE dim_module_presentation (
    module_presentation_key INT NOT NULL AUTO_INCREMENT,
    code_module VARCHAR(5) NOT NULL,
    code_presentation VARCHAR(5) NOT NULL,
    presentation_year SMALLINT NOT NULL,
    presentation_term CHAR(1) NOT NULL,
    module_presentation_length INT NOT NULL,

    CONSTRAINT pk_dim_module_presentation
        PRIMARY KEY (module_presentation_key),

    CONSTRAINT uq_dim_module_presentation
        UNIQUE (code_module, code_presentation),

    CONSTRAINT chk_dim_presentation_term
        CHECK (presentation_term IN ('B', 'J')),

    CONSTRAINT chk_dim_module_length
        CHECK (module_presentation_length > 0)
) ENGINE=InnoDB;

-- Load the dimension

INSERT INTO dim_module_presentation (
    code_module,
    code_presentation,
    presentation_year,
    presentation_term,
    module_presentation_length
)
SELECT
    code_module,
    code_presentation,
    CAST(LEFT(code_presentation, 4) AS UNSIGNED),
    RIGHT(code_presentation, 1),
    module_presentation_length
FROM oulad_etl.clean_module_presentation
ORDER BY code_module, code_presentation;

SELECT
    COUNT(*) AS dimension_rows,
    COUNT(DISTINCT module_presentation_key) AS unique_warehouse_keys,
    COUNT(
        DISTINCT CONCAT(code_module, '-', code_presentation)
    ) AS unique_module_presentations
FROM dim_module_presentation;

SELECT
    code_module,
    code_presentation,
    COUNT(*) AS number_of_records
FROM dim_module_presentation
GROUP BY code_module, code_presentation
HAVING COUNT(*) > 1;

SELECT *
FROM dim_module_presentation
ORDER BY code_module, code_presentation;

-- =====================================================
-- SECTION 5: Create and load age-band dimension
-- =====================================================

USE oulad_dw;

DROP TABLE IF EXISTS dim_age_band;

CREATE TABLE dim_age_band (
    age_band_key INT NOT NULL AUTO_INCREMENT,
    age_band VARCHAR(10) NOT NULL,
    age_band_order TINYINT NOT NULL,

    CONSTRAINT pk_dim_age_band
        PRIMARY KEY (age_band_key),

    CONSTRAINT uq_dim_age_band
        UNIQUE (age_band),

    CONSTRAINT chk_dim_age_band
        CHECK (age_band IN ('0-35', '35-55', '55<=')),

    CONSTRAINT chk_dim_age_order
        CHECK (age_band_order BETWEEN 1 AND 3)
) ENGINE=InnoDB;

INSERT INTO dim_age_band (
    age_band,
    age_band_order
)
SELECT DISTINCT
    age_band,
    CASE
        WHEN age_band = '0-35' THEN 1
        WHEN age_band = '35-55' THEN 2
        WHEN age_band = '55<=' THEN 3
    END AS age_band_order
FROM oulad_etl.clean_registration
WHERE age_band IS NOT NULL
ORDER BY age_band_order;

SELECT
    COUNT(*) AS dimension_rows,
    COUNT(DISTINCT age_band_key) AS unique_warehouse_keys,
    COUNT(DISTINCT age_band) AS unique_age_bands
FROM dim_age_band;

SELECT *
FROM dim_age_band
ORDER BY age_band_order;

-- =====================================================
-- SECTION 6: Create and load outcome dimension
-- =====================================================

USE oulad_dw;

DROP TABLE IF EXISTS dim_outcome;

CREATE TABLE dim_outcome (
    outcome_key INT NOT NULL AUTO_INCREMENT,
    final_result VARCHAR(20) NOT NULL,
    outcome_category VARCHAR(20) NOT NULL,
    successful_completion TINYINT(1) NOT NULL,
    outcome_order TINYINT NOT NULL,

    CONSTRAINT pk_dim_outcome
        PRIMARY KEY (outcome_key),

    CONSTRAINT uq_dim_outcome
        UNIQUE (final_result),

    CONSTRAINT chk_dim_outcome_result
        CHECK (
            final_result IN (
                'Distinction',
                'Pass',
                'Fail',
                'Withdrawn'
            )
        ),

    CONSTRAINT chk_dim_outcome_success
        CHECK (successful_completion IN (0, 1))
) ENGINE=InnoDB;


INSERT INTO dim_outcome (
    final_result,
    outcome_category,
    successful_completion,
    outcome_order
)
SELECT DISTINCT
    final_result,

    CASE
        WHEN final_result IN ('Distinction', 'Pass')
            THEN 'Successful'
        WHEN final_result = 'Fail'
            THEN 'Unsuccessful'
        WHEN final_result = 'Withdrawn'
            THEN 'Withdrawn'
    END AS outcome_category,

    CASE
        WHEN final_result IN ('Distinction', 'Pass')
            THEN 1
        ELSE 0
    END AS successful_completion,

    CASE
        WHEN final_result = 'Distinction' THEN 1
        WHEN final_result = 'Pass' THEN 2
        WHEN final_result = 'Fail' THEN 3
        WHEN final_result = 'Withdrawn' THEN 4
    END AS outcome_order

FROM oulad_etl.clean_registration
WHERE final_result IS NOT NULL
ORDER BY outcome_order;

SELECT
    COUNT(*) AS dimension_rows,
    COUNT(DISTINCT outcome_key) AS unique_warehouse_keys,
    COUNT(DISTINCT final_result) AS unique_results
FROM dim_outcome;

SELECT *
FROM dim_outcome
ORDER BY outcome_order;


-- =====================================================
-- SECTION 7: Create the learning-engagement fact table
-- Grain: one student registration per module presentation
-- =====================================================

USE oulad_dw;

DROP TABLE IF EXISTS fact_learning_engagement;

CREATE TABLE fact_learning_engagement (
    engagement_fact_key BIGINT NOT NULL AUTO_INCREMENT,

    -- Dimension foreign keys
    student_key INT NOT NULL,
    module_presentation_key INT NOT NULL,
    age_band_key INT NOT NULL,
    outcome_key INT NOT NULL,

    -- Registration measures
    studied_credits INT NOT NULL,
    previous_attempts INT NOT NULL,

    -- Engagement measures
    total_clicks BIGINT NOT NULL DEFAULT 0,
    active_days INT NOT NULL DEFAULT 0,
    resources_used INT NOT NULL DEFAULT 0,

    -- Assessment measures
    assessment_submissions INT NOT NULL DEFAULT 0,
    average_score DECIMAL(5,2),

    CONSTRAINT pk_fact_learning_engagement
        PRIMARY KEY (engagement_fact_key),

    -- Prevent more than one fact for the same
    -- student and module presentation
    CONSTRAINT uq_fact_student_presentation
        UNIQUE (student_key, module_presentation_key),

    CONSTRAINT fk_fact_student
        FOREIGN KEY (student_key)
        REFERENCES dim_student (student_key),

    CONSTRAINT fk_fact_module_presentation
        FOREIGN KEY (module_presentation_key)
        REFERENCES dim_module_presentation (
            module_presentation_key
        ),

    CONSTRAINT fk_fact_age_band
        FOREIGN KEY (age_band_key)
        REFERENCES dim_age_band (age_band_key),

    CONSTRAINT fk_fact_outcome
        FOREIGN KEY (outcome_key)
        REFERENCES dim_outcome (outcome_key),

    CONSTRAINT chk_fact_credits
        CHECK (studied_credits > 0),

    CONSTRAINT chk_fact_attempts
        CHECK (previous_attempts >= 0),

    CONSTRAINT chk_fact_clicks
        CHECK (total_clicks >= 0),

    CONSTRAINT chk_fact_active_days
        CHECK (active_days >= 0),

    CONSTRAINT chk_fact_resources
        CHECK (resources_used >= 0),

    CONSTRAINT chk_fact_submissions
        CHECK (assessment_submissions >= 0),

    CONSTRAINT chk_fact_average_score
        CHECK (
            average_score IS NULL
            OR average_score BETWEEN 0 AND 100
        )
) ENGINE=InnoDB;

SHOW TABLES;

DESCRIBE fact_learning_engagement;

SELECT COUNT(*) AS fact_rows_before_loading

-- =====================================================
-- SECTION 8: Populate the learning-engagement fact table
-- =====================================================

USE oulad_dw;

TRUNCATE TABLE fact_learning_engagement;

INSERT INTO fact_learning_engagement (
    student_key,
    module_presentation_key,
    age_band_key,
    outcome_key,
    studied_credits,
    previous_attempts,
    total_clicks,
    active_days,
    resources_used,
    assessment_submissions,
    average_score
)
SELECT
    ds.student_key,
    dmp.module_presentation_key,
    dab.age_band_key,
    dout.outcome_key,
    r.studied_credits,
    r.num_of_prev_attempts,
    a.total_clicks,
    a.active_days,
    a.resources_used,
    a.assessment_submissions,
    a.average_score
FROM oulad_etl.clean_registration AS r

JOIN oulad_etl.analytics_student_engagement AS a
    ON a.id_student = r.id_student
   AND a.code_module = r.code_module
   AND a.code_presentation = r.code_presentation

JOIN oulad_dw.dim_student AS ds
    ON ds.id_student = r.id_student

JOIN oulad_dw.dim_module_presentation AS dmp
    ON dmp.code_module = r.code_module
   AND dmp.code_presentation = r.code_presentation

JOIN oulad_dw.dim_age_band AS dab
    ON dab.age_band = r.age_band

JOIN oulad_dw.dim_outcome AS dout
    ON dout.final_result = r.final_result;
FROM fact_learning_engagement;

SELECT
    COUNT(*) AS fact_rows,
    32593 AS expected_rows,
    COUNT(*) - 32593 AS difference
FROM fact_learning_engagement;

SELECT
    student_key,
    module_presentation_key,
    COUNT(*) AS number_of_facts
FROM fact_learning_engagement
GROUP BY
    student_key,
    module_presentation_key
HAVING COUNT(*) > 1;


SELECT
    SUM(ds.student_key IS NULL) AS unmatched_students,
    SUM(dmp.module_presentation_key IS NULL)
        AS unmatched_module_presentations,
    SUM(dab.age_band_key IS NULL) AS unmatched_age_bands,
    SUM(dout.outcome_key IS NULL) AS unmatched_outcomes
FROM fact_learning_engagement AS f

LEFT JOIN dim_student AS ds
    ON ds.student_key = f.student_key

LEFT JOIN dim_module_presentation AS dmp
    ON dmp.module_presentation_key =
       f.module_presentation_key

LEFT JOIN dim_age_band AS dab
    ON dab.age_band_key = f.age_band_key

LEFT JOIN dim_outcome AS dout
    ON dout.outcome_key = f.outcome_key;
    
    
    
    SELECT
    f.engagement_fact_key,
    ds.id_student,
    dmp.code_module,
    dmp.code_presentation,
    dab.age_band,
    dout.final_result,
    f.studied_credits,
    f.total_clicks,
    f.active_days,
    f.resources_used,
    f.assessment_submissions,
    f.average_score
FROM fact_learning_engagement AS f

JOIN dim_student AS ds
    ON ds.student_key = f.student_key

JOIN dim_module_presentation AS dmp
    ON dmp.module_presentation_key =
       f.module_presentation_key

JOIN dim_age_band AS dab
    ON dab.age_band_key = f.age_band_key

JOIN dim_outcome AS dout
    ON dout.outcome_key = f.outcome_key

ORDER BY f.engagement_fact_key
LIMIT 20;