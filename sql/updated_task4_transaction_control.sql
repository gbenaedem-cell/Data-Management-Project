/*=========================================================
  TASK 4 - CONTROLLED ASSESSMENT SCORE CORRECTION
=========================================================*/

START TRANSACTION;

-- Display the original assessment score
SELECT *
FROM student_assessment
WHERE id_student = 11391
AND id_assessment = 1752;

-- Create a savepoint
SAVEPOINT before_score_update;

-- Correct the student's assessment score
UPDATE student_assessment
SET score = 85
WHERE id_student = 11391
AND id_assessment = 1752;

-- Verify the correction
SELECT *
FROM student_assessment
WHERE id_student = 11391
AND id_assessment = 1752;

-- Attempt an invalid score
UPDATE student_assessment
SET score = 120
WHERE id_student = 11391
AND id_assessment = 1752;

-- Restore the database to the savepoint
ROLLBACK TO SAVEPOINT before_score_update;

-- Final verification
SELECT *
FROM student_assessment
WHERE id_student = 11391
AND id_assessment = 1752;



-- Demostration Data Setup

INSERT INTO module_presentation VALUES
('AAA','2026A',268);

INSERT INTO student VALUES
(11391,'M','Scotland','A Level or Equivalent','50-60%','N');

INSERT INTO registration VALUES
(11391,'AAA','2026A','0-35',-10,NULL,0,60,'Pass');

INSERT INTO assessment VALUES
(1752,'AAA','2026A','TMA',19,10);

INSERT INTO student_assessment VALUES
(1752,11391,'AAA','2026A',18,0,78);