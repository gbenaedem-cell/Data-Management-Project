USE oulad_db;

SELECT COUNT(*) AS existing_test_student
FROM student
WHERE id_student = 99999999;

-- SECTION 2: Begin transaction and insert a controlled test record
START TRANSACTION;

INSERT INTO student (
    id_student,
    gender,
    region,
    highest_education,
    imd_band,
    disability
)
VALUES (
    99999999,
    'F',
    'Test Region',
    'A Level or Equivalent',
    '50-60%',
    'N'
);

SAVEPOINT student_inserted;

-- Verify the temporary record inside the transaction
SELECT *
FROM student
WHERE id_student = 99999999;

-- SECTION 3: Controlled update/correction
UPDATE student
SET region = 'Scotland'
WHERE id_student = 99999999;

SELECT ROW_COUNT() AS rows_corrected;

SELECT
    id_student,
    region
FROM student
WHERE id_student = 99999999;

-- SECTION 4: Deliberately attempt an invalid update
UPDATE student
SET gender = 'X'
WHERE id_student = 99999999;

-- SECTION 5A: Verify that the invalid gender was rejected
SELECT
    'After failed constraint test' AS transaction_stage,
    id_student,
    gender,
    region
FROM student
WHERE id_student = 99999999;

-- Undo everything performed after SAVEPOINT student_inserted
ROLLBACK TO SAVEPOINT student_inserted;

-- SECTION 5B: Verify that the region correction was reversed
SELECT
    'After savepoint rollback' AS transaction_stage,
    id_student,
    gender,
    region
FROM student
WHERE id_student = 99999999;

-- SECTION 6: Roll back the complete transaction
ROLLBACK;

-- Confirm that the temporary student was removed
SELECT COUNT(*) AS test_student_after_full_rollback
FROM student
WHERE id_student = 99999999;

-- Confirm that the original student-table count is unchanged
SELECT COUNT(*) AS final_student_count
FROM student;

SELECT s.*
FROM student AS s
LEFT JOIN (
    SELECT DISTINCT
        CAST(TRIM(id_student) AS UNSIGNED) AS id_student
    FROM stg_student_info
    WHERE TRIM(id_student) REGEXP '^[0-9]+$'
) AS source_students
    ON source_students.id_student = s.id_student
WHERE source_students.id_student IS NULL;

SELECT
    (SELECT COUNT(*) FROM student) AS final_students,
    (
        SELECT COUNT(DISTINCT CAST(TRIM(id_student) AS UNSIGNED))
        FROM stg_student_info
        WHERE TRIM(id_student) REGEXP '^[0-9]+$'
    ) AS source_unique_students;