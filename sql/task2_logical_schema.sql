-- OULAD Task 2: Logical relational schema
-- Purpose: import this CREATE script into MySQL Workbench to generate an EER diagram.
-- This file is model-only. Do not execute it against oulad_db while data is importing.

CREATE SCHEMA IF NOT EXISTS oulad_task2_model;
USE oulad_task2_model;

-- A particular delivery of an Open University module.
CREATE TABLE module_presentation (
    code_module VARCHAR(5) NOT NULL,
    code_presentation VARCHAR(5) NOT NULL,
    module_presentation_length INT NOT NULL,
    CONSTRAINT pk_module_presentation
        PRIMARY KEY (code_module, code_presentation),
    CONSTRAINT chk_presentation_length
        CHECK (module_presentation_length > 0)
);

-- Attributes found to be stable for each student in the inspected dataset.
CREATE TABLE student (
    id_student INT NOT NULL,
    gender CHAR(1) NOT NULL,
    region VARCHAR(50) NOT NULL,
    highest_education VARCHAR(40) NOT NULL,
    imd_band VARCHAR(10) NULL,
    disability CHAR(1) NOT NULL,
    CONSTRAINT pk_student
        PRIMARY KEY (id_student),
    CONSTRAINT chk_student_gender
        CHECK (gender IN ('M', 'F')),
    CONSTRAINT chk_student_disability
        CHECK (disability IN ('Y', 'N')),
    CONSTRAINT chk_student_imd_band
        CHECK (
            imd_band IS NULL OR imd_band IN (
                '0-10%', '10-20%', '20-30%', '30-40%', '40-50%',
                '50-60%', '60-70%', '70-80%', '80-90%', '90-100%'
            )
        )
);

-- One student's enrolment in one module presentation.
-- age_band is stored here because 72 students changed age band across presentations.
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
    CONSTRAINT chk_registration_dates
        CHECK (
            date_registration IS NULL
            OR date_unregistration IS NULL
            OR date_unregistration >= date_registration
        )
);

-- An assessment belonging to a module presentation.
CREATE TABLE assessment (
    id_assessment INT NOT NULL,
    code_module VARCHAR(5) NOT NULL,
    code_presentation VARCHAR(5) NOT NULL,
    assessment_type VARCHAR(10) NOT NULL,
    assessment_date INT NULL,
    weight DECIMAL(5,2) NOT NULL,
    CONSTRAINT pk_assessment
        PRIMARY KEY (id_assessment),
    CONSTRAINT uq_assessment_context
        UNIQUE (id_assessment, code_module, code_presentation),
    CONSTRAINT fk_assessment_presentation
        FOREIGN KEY (code_module, code_presentation)
        REFERENCES module_presentation (code_module, code_presentation),
    CONSTRAINT chk_assessment_type
        CHECK (assessment_type IN ('TMA', 'CMA', 'Exam')),
    CONSTRAINT chk_assessment_weight
        CHECK (weight BETWEEN 0 AND 100)
);

-- An online learning resource made available in a module presentation.
CREATE TABLE vle_resource (
    id_site INT NOT NULL,
    code_module VARCHAR(5) NOT NULL,
    code_presentation VARCHAR(5) NOT NULL,
    activity_type VARCHAR(50) NOT NULL,
    week_from INT NULL,
    week_to INT NULL,
    CONSTRAINT pk_vle_resource
        PRIMARY KEY (id_site),
    CONSTRAINT uq_vle_resource_context
        UNIQUE (id_site, code_module, code_presentation),
    CONSTRAINT fk_vle_resource_presentation
        FOREIGN KEY (code_module, code_presentation)
        REFERENCES module_presentation (code_module, code_presentation),
    CONSTRAINT chk_vle_resource_weeks
        CHECK (
            (week_from IS NULL AND week_to IS NULL)
            OR
            (
                week_from IS NOT NULL
                AND week_to IS NOT NULL
                AND week_from >= 0
                AND week_to >= week_from
            )
        )
);

-- A student's submission/result for an assessment.
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
        CHECK (score IS NULL OR score BETWEEN 0 AND 100)
);

-- A student's aggregated daily interaction with one VLE resource.
CREATE TABLE student_vle_interaction (
    code_module VARCHAR(5) NOT NULL,
    code_presentation VARCHAR(5) NOT NULL,
    id_student INT NOT NULL,
    id_site INT NOT NULL,
    interaction_date INT NOT NULL,
    sum_click INT NOT NULL,
    CONSTRAINT pk_student_vle_interaction
        PRIMARY KEY (
            code_module,
            code_presentation,
            id_student,
            id_site,
            interaction_date
        ),
    CONSTRAINT fk_student_vle_registration
        FOREIGN KEY (id_student, code_module, code_presentation)
        REFERENCES registration (id_student, code_module, code_presentation),
    CONSTRAINT fk_student_vle_resource
        FOREIGN KEY (id_site, code_module, code_presentation)
        REFERENCES vle_resource (id_site, code_module, code_presentation)
);

