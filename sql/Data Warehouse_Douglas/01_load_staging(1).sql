
-- 01_load_staging.sql  (Windows-friendly version, hardcoded paths)


TRUNCATE staging.courses, staging.assessments, staging.student_info,
         staging.student_assessment, staging.student_registration,
         staging.vle, staging.student_vle;

\copy staging.courses (code_module, code_presentation, module_presentation_length) FROM 'C:/anonymisedData/courses.csv' WITH (FORMAT csv, HEADER true)

\copy staging.assessments (code_module, code_presentation, id_assessment, assessment_type, date, weight) FROM 'C:/anonymisedData/assessments.csv' WITH (FORMAT csv, HEADER true, FORCE_NULL(date))

\copy staging.student_info (code_module, code_presentation, id_student, gender, region, highest_education, imd_band, age_band, num_of_prev_attempts, studied_credits, disability, final_result) FROM 'C:/anonymisedData/studentInfo.csv' WITH (FORMAT csv, HEADER true, FORCE_NULL(imd_band))

\copy staging.student_registration (code_module, code_presentation, id_student, date_registration, date_unregistration) FROM 'C:/anonymisedData/studentRegistration.csv' WITH (FORMAT csv, HEADER true, FORCE_NULL(date_registration, date_unregistration))

\copy staging.student_assessment (id_assessment, id_student, date_submitted, is_banked, score) FROM 'C:/anonymisedData/studentAssessment.csv' WITH (FORMAT csv, HEADER true, FORCE_NULL(score))

\copy staging.vle (id_site, code_module, code_presentation, activity_type, week_from, week_to) FROM 'C:/anonymisedData/vle.csv' WITH (FORMAT csv, HEADER true, FORCE_NULL(week_from, week_to))

-- Big one: 10.65M rows / ~454MB. This will take a while.
\copy staging.student_vle (code_module, code_presentation, id_student, id_site, date, sum_clicks) FROM 'C:/anonymisedData/studentVle.csv' WITH (FORMAT csv, HEADER true)

-- ------------------------------------------------------------
-- Verification
-- ------------------------------------------------------------
SELECT 'staging.courses' AS tbl, COUNT(*) FROM staging.courses
UNION ALL SELECT 'staging.assessments', COUNT(*) FROM staging.assessments
UNION ALL SELECT 'staging.student_info', COUNT(*) FROM staging.student_info
UNION ALL SELECT 'staging.student_registration', COUNT(*) FROM staging.student_registration
UNION ALL SELECT 'staging.student_assessment', COUNT(*) FROM staging.student_assessment
UNION ALL SELECT 'staging.vle', COUNT(*) FROM staging.vle
UNION ALL SELECT 'staging.student_vle', COUNT(*) FROM staging.student_vle;
