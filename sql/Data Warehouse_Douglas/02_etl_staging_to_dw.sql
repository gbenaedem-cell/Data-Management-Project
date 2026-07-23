-- ============================================================
-- 02_etl_staging_to_dw.sql
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. dim_date  (conformed date dimension, offsets -100..300 days
-- ------------------------------------------------------------
TRUNCATE dw.dim_date;
INSERT INTO dw.dim_date (date_key, week_number, is_before_start)
SELECT d, d / 7, (d < 0)
FROM generate_series(-150, 300) AS d;

-- ------------------------------------------------------------
-- 2. dim_course
-- ------------------------------------------------------------
TRUNCATE dw.dim_course CASCADE;
INSERT INTO dw.dim_course (code_module, code_presentation, module_presentation_length)
SELECT DISTINCT code_module, code_presentation, module_presentation_length
FROM staging.courses;

-- ------------------------------------------------------------
-- 3. dim_student
-- ------------------------------------------------------------
TRUNCATE dw.dim_student CASCADE;
INSERT INTO dw.dim_student (id_student, gender, region, highest_education, imd_band, age_band, disability)
SELECT DISTINCT ON (id_student)
       id_student, gender, region, highest_education,
       COALESCE(imd_band, 'Unknown') AS imd_band,
       age_band, disability
FROM staging.student_info
ORDER BY id_student, code_presentation;  -- deterministic pick

-- ------------------------------------------------------------
-- 4. dim_assessment
-- ------------------------------------------------------------
TRUNCATE dw.dim_assessment CASCADE;
INSERT INTO dw.dim_assessment (id_assessment, course_key, assessment_type, assessment_date_days, weight)
SELECT DISTINCT ON (a.id_assessment)
       a.id_assessment, c.course_key, a.assessment_type,
       a.date::INT,          -- stays NULL for the 11 Exam-type rows
       a.weight
FROM staging.assessments a
JOIN dw.dim_course c
  ON a.code_module = c.code_module AND a.code_presentation = c.code_presentation;

-- ------------------------------------------------------------
-- 5. dim_vle_material
-- ------------------------------------------------------------
TRUNCATE dw.dim_vle_material CASCADE;
INSERT INTO dw.dim_vle_material (id_site, course_key, activity_type, week_from, week_to)
SELECT DISTINCT ON (v.id_site)
       v.id_site, c.course_key, v.activity_type,
       v.week_from::INT, v.week_to::INT
FROM staging.vle v
JOIN dw.dim_course c
  ON v.code_module = c.code_module AND v.code_presentation = c.code_presentation;

-- ------------------------------------------------------------
-- 6. fact_student_enrollment
-- ------------------------------------------------------------
TRUNCATE dw.fact_student_enrollment;
INSERT INTO dw.fact_student_enrollment
    (student_key, course_key, date_registration, date_unregistration,
     num_of_prev_attempts, studied_credits, final_result)
SELECT s.student_key, c.course_key,
       sr.date_registration::INT,
       sr.date_unregistration::INT,     -- NULL = never unregistered
       si.num_of_prev_attempts, si.studied_credits, si.final_result
FROM staging.student_info si
JOIN dw.dim_student s ON si.id_student = s.id_student
JOIN dw.dim_course  c ON si.code_module = c.code_module AND si.code_presentation = c.code_presentation
LEFT JOIN staging.student_registration sr
       ON si.id_student = sr.id_student
      AND si.code_module = sr.code_module
      AND si.code_presentation = sr.code_presentation
ON CONFLICT (student_key, course_key) DO NOTHING;

-- ------------------------------------------------------------
-- 7. fact_student_assessment
-- ------------------------------------------------------------
TRUNCATE dw.fact_student_assessment;
INSERT INTO dw.fact_student_assessment
    (student_key, assessment_key, date_submitted, is_banked, score, submission_delay_days)
SELECT s.student_key, a.assessment_key, sa.date_submitted,
       (sa.is_banked = 1) AS is_banked,
       sa.score,                                       -- NULL for 173 ungraded rows
       sa.date_submitted - a.assessment_date_days AS submission_delay_days
FROM staging.student_assessment sa
JOIN dw.dim_student s ON sa.id_student = s.id_student
JOIN dw.dim_assessment a ON sa.id_assessment = a.id_assessment
ON CONFLICT (student_key, assessment_key) DO NOTHING;

-- ------------------------------------------------------------
-- 8. fact_student_vle  (the big one — 10.65M source rows)
-- ------------------------------------------------------------
TRUNCATE dw.fact_student_vle;
INSERT INTO dw.fact_student_vle
    (student_key, course_key, vle_key, interaction_date, sum_clicks)
SELECT s.student_key, c.course_key, v.vle_key, sv.date, sv.sum_clicks
FROM staging.student_vle sv
JOIN dw.dim_student s ON sv.id_student = s.id_student
JOIN dw.dim_course  c ON sv.code_module = c.code_module AND sv.code_presentation = c.code_presentation
JOIN dw.dim_vle_material v ON sv.id_site = v.id_site;

COMMIT;

-- ------------------------------------------------------------
-- Post-load verification
-- ------------------------------------------------------------
SELECT 'dim_course' AS t, COUNT(*) FROM dw.dim_course
UNION ALL SELECT 'dim_student', COUNT(*) FROM dw.dim_student
UNION ALL SELECT 'dim_assessment', COUNT(*) FROM dw.dim_assessment
UNION ALL SELECT 'dim_vle_material', COUNT(*) FROM dw.dim_vle_material
UNION ALL SELECT 'dim_date', COUNT(*) FROM dw.dim_date
UNION ALL SELECT 'fact_student_enrollment', COUNT(*) FROM dw.fact_student_enrollment
UNION ALL SELECT 'fact_student_assessment', COUNT(*) FROM dw.fact_student_assessment
UNION ALL SELECT 'fact_student_vle', COUNT(*) FROM dw.fact_student_vle;
