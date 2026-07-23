USE oulad_db;

CREATE TABLE IF NOT EXISTS stg_courses (
    code_module VARCHAR(20),
    code_presentation VARCHAR(20),
    module_presentation_length VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS stg_assessments (
    code_module VARCHAR(20),
    code_presentation VARCHAR(20),
    id_assessment VARCHAR(20),
    assessment_type VARCHAR(20),
    `date` VARCHAR(20),
    weight VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS stg_vle (
    id_site VARCHAR(20),
    code_module VARCHAR(20),
    code_presentation VARCHAR(20),
    activity_type VARCHAR(50),
    week_from VARCHAR(20),
    week_to VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS stg_student_info (
    code_module VARCHAR(20),
    code_presentation VARCHAR(20),
    id_student VARCHAR(20),
    gender VARCHAR(10),
    region VARCHAR(100),
    highest_education VARCHAR(50),
    imd_band VARCHAR(20),
    age_band VARCHAR(20),
    num_of_prev_attempts VARCHAR(20),
    studied_credits VARCHAR(20),
    disability VARCHAR(10),
    final_result VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS stg_student_registration (
    code_module VARCHAR(20),
    code_presentation VARCHAR(20),
    id_student VARCHAR(20),
    date_registration VARCHAR(20),
    date_unregistration VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS stg_student_assessment (
    id_assessment VARCHAR(20),
    id_student VARCHAR(20),
    date_submitted VARCHAR(20),
    is_banked VARCHAR(10),
    score VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS stg_student_vle (
    code_module VARCHAR(20),
    code_presentation VARCHAR(20),
    id_student VARCHAR(20),
    id_site VARCHAR(20),
    `date` VARCHAR(20),
    sum_click VARCHAR(20)
);

SHOW TABLES;