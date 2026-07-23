USE oulad_db;

SELECT COUNT(*) AS total_rows
FROM stg_courses;

SELECT *
FROM stg_courses
LIMIT 10;


SELECT
    SUM(CASE WHEN code_module IS NULL OR TRIM(code_module) = ''
        THEN 1 ELSE 0 END) AS missing_code_module,

    SUM(CASE WHEN code_presentation IS NULL OR TRIM(code_presentation) = ''
        THEN 1 ELSE 0 END) AS missing_code_presentation,

    SUM(CASE WHEN module_presentation_length IS NULL
                  OR TRIM(module_presentation_length) = ''
        THEN 1 ELSE 0 END) AS missing_presentation_length
FROM stg_courses;


SELECT
    code_module,
    code_presentation,
    COUNT(*) AS number_of_records
FROM stg_courses
GROUP BY code_module, code_presentation
HAVING COUNT(*) > 1;


SELECT *
FROM stg_courses
WHERE TRIM(code_module) NOT REGEXP '^[A-Z]{3}$'
   OR TRIM(code_presentation) NOT REGEXP '^[0-9]{4}[BJ]$'
   OR TRIM(module_presentation_length) NOT REGEXP '^[0-9]+$'
   OR CAST(module_presentation_length AS UNSIGNED) <= 0;
   
   SELECT
    COUNT(DISTINCT code_module) AS unique_modules,
    COUNT(DISTINCT code_presentation) AS unique_presentations,
    MIN(CAST(module_presentation_length AS UNSIGNED)) AS shortest_length_days,
    MAX(CAST(module_presentation_length AS UNSIGNED)) AS longest_length_days,
    ROUND(AVG(CAST(module_presentation_length AS UNSIGNED)), 2)
        AS average_length_days
FROM stg_courses;

SELECT COUNT(*) AS total_rows
FROM stg_assessments;

SELECT *
FROM stg_assessments
LIMIT 10;

SELECT
    SUM(CASE WHEN code_module IS NULL
                  OR TRIM(code_module) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_code_module,

    SUM(CASE WHEN code_presentation IS NULL
                  OR TRIM(code_presentation) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_code_presentation,

    SUM(CASE WHEN id_assessment IS NULL
                  OR TRIM(id_assessment) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_id_assessment,

    SUM(CASE WHEN assessment_type IS NULL
                  OR TRIM(assessment_type) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_assessment_type,

    SUM(CASE WHEN `date` IS NULL
                  OR TRIM(`date`) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_date,

    SUM(CASE WHEN weight IS NULL
                  OR TRIM(weight) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_weight
FROM stg_assessments;

SELECT
    assessment_type,
    COUNT(*) AS missing_date_count
FROM stg_assessments
WHERE `date` IS NULL
   OR TRIM(`date`) IN ('', '?')
GROUP BY assessment_type;

SELECT
    id_assessment,
    COUNT(*) AS number_of_records
FROM stg_assessments
GROUP BY id_assessment
HAVING COUNT(*) > 1;

SELECT
    a.code_module,
    a.code_presentation,
    COUNT(*) AS unmatched_records
FROM stg_assessments AS a
LEFT JOIN stg_courses AS c
    ON a.code_module = c.code_module
   AND a.code_presentation = c.code_presentation
WHERE c.code_module IS NULL
GROUP BY
    a.code_module,
    a.code_presentation;
    
    SELECT
    assessment_type,
    COUNT(*) AS number_of_assessments,

    MIN(
        CAST(NULLIF(TRIM(`date`), '?') AS SIGNED)
    ) AS earliest_deadline_day,

    MAX(
        CAST(NULLIF(TRIM(`date`), '?') AS SIGNED)
    ) AS latest_deadline_day,

    MIN(CAST(weight AS DECIMAL(5,2))) AS minimum_weight,

    MAX(CAST(weight AS DECIMAL(5,2))) AS maximum_weight

FROM stg_assessments
GROUP BY assessment_type
ORDER BY assessment_type;

SELECT
    assessment_type,
    COUNT(*) AS zero_weight_assessments
FROM stg_assessments
WHERE CAST(weight AS DECIMAL(5,2)) = 0
GROUP BY assessment_type;

SELECT
    a.code_module,
    a.code_presentation,
    a.id_assessment,
    a.assessment_type,
    a.`date` AS deadline_day,
    c.module_presentation_length
FROM stg_assessments AS a
JOIN stg_courses AS c
    ON a.code_module = c.code_module
   AND a.code_presentation = c.code_presentation
WHERE TRIM(a.`date`) NOT IN ('', '?')
  AND (
       CAST(a.`date` AS SIGNED) < 0
       OR CAST(a.`date` AS SIGNED) >
          CAST(c.module_presentation_length AS SIGNED)
  );
  
  SELECT COUNT(*) AS total_rows
FROM stg_vle;

SELECT *
FROM stg_vle
LIMIT 10;

SELECT
    SUM(CASE WHEN id_site IS NULL OR TRIM(id_site) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_id_site,

    SUM(CASE WHEN code_module IS NULL OR TRIM(code_module) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_code_module,

    SUM(CASE WHEN code_presentation IS NULL
                  OR TRIM(code_presentation) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_code_presentation,

    SUM(CASE WHEN activity_type IS NULL
                  OR TRIM(activity_type) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_activity_type,

    SUM(CASE WHEN week_from IS NULL OR TRIM(week_from) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_week_from,

    SUM(CASE WHEN week_to IS NULL OR TRIM(week_to) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_week_to
FROM stg_vle;

SELECT
    SUM(
        CASE
            WHEN (week_from IS NULL OR TRIM(week_from) IN ('', '?'))
             AND (week_to IS NULL OR TRIM(week_to) IN ('', '?'))
            THEN 1 ELSE 0
        END
    ) AS both_weeks_missing,

    SUM(
        CASE
            WHEN (week_from IS NULL OR TRIM(week_from) IN ('', '?'))
             AND NOT (week_to IS NULL OR TRIM(week_to) IN ('', '?'))
            THEN 1 ELSE 0
        END
    ) AS only_week_from_missing,

    SUM(
        CASE
            WHEN NOT (week_from IS NULL OR TRIM(week_from) IN ('', '?'))
             AND (week_to IS NULL OR TRIM(week_to) IN ('', '?'))
            THEN 1 ELSE 0
        END
    ) AS only_week_to_missing
FROM stg_vle;

SELECT
    id_site,
    COUNT(*) AS number_of_records
FROM stg_vle
GROUP BY id_site
HAVING COUNT(*) > 1;

SELECT
    v.code_module,
    v.code_presentation,
    COUNT(*) AS unmatched_records
FROM stg_vle AS v
LEFT JOIN stg_courses AS c
    ON v.code_module = c.code_module
   AND v.code_presentation = c.code_presentation
WHERE c.code_module IS NULL
GROUP BY
    v.code_module,
    v.code_presentation;
    
    SELECT
    activity_type,
    COUNT(*) AS number_of_resources
FROM stg_vle
GROUP BY activity_type
ORDER BY number_of_resources DESC;

SELECT
    COUNT(*) AS resources_with_week_information,

    MIN(CAST(week_from AS SIGNED)) AS earliest_week_from,

    MAX(CAST(week_to AS SIGNED)) AS latest_week_to,

    SUM(
        CASE
            WHEN CAST(week_from AS SIGNED) >
                 CAST(week_to AS SIGNED)
            THEN 1 ELSE 0
        END
    ) AS reversed_week_ranges,

    SUM(
        CASE
            WHEN CAST(week_from AS SIGNED) < 0
              OR CAST(week_to AS SIGNED) < 0
            THEN 1 ELSE 0
        END
    ) AS negative_week_records

FROM stg_vle
WHERE TRIM(week_from) NOT IN ('', '?')
  AND TRIM(week_to) NOT IN ('', '?');
  
  SELECT COUNT(*) AS total_rows
FROM stg_student_info;

SELECT *
FROM stg_student_info
LIMIT 10;

SELECT
    SUM(CASE WHEN code_module IS NULL OR TRIM(code_module) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_code_module,

    SUM(CASE WHEN code_presentation IS NULL
                  OR TRIM(code_presentation) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_code_presentation,

    SUM(CASE WHEN id_student IS NULL OR TRIM(id_student) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_id_student,

    SUM(CASE WHEN gender IS NULL OR TRIM(gender) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_gender,

    SUM(CASE WHEN region IS NULL OR TRIM(region) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_region,

    SUM(CASE WHEN highest_education IS NULL
                  OR TRIM(highest_education) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_highest_education,

    SUM(CASE WHEN imd_band IS NULL OR TRIM(imd_band) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_imd_band,

    SUM(CASE WHEN age_band IS NULL OR TRIM(age_band) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_age_band,

    SUM(CASE WHEN num_of_prev_attempts IS NULL
                  OR TRIM(num_of_prev_attempts) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_previous_attempts,

    SUM(CASE WHEN studied_credits IS NULL
                  OR TRIM(studied_credits) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_studied_credits,

    SUM(CASE WHEN disability IS NULL OR TRIM(disability) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_disability,

    SUM(CASE WHEN final_result IS NULL OR TRIM(final_result) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_final_result
FROM stg_student_info;

SELECT
    code_module,
    code_presentation,
    COUNT(*) AS missing_imd_records
FROM stg_student_info
WHERE imd_band IS NULL
   OR TRIM(imd_band) IN ('', '?')
GROUP BY
    code_module,
    code_presentation
ORDER BY missing_imd_records DESC;

SELECT
    id_student,
    code_module,
    code_presentation,
    COUNT(*) AS number_of_records
FROM stg_student_info
GROUP BY
    id_student,
    code_module,
    code_presentation
HAVING COUNT(*) > 1;

SELECT
    s.code_module,
    s.code_presentation,
    COUNT(*) AS unmatched_records
FROM stg_student_info AS s
LEFT JOIN stg_courses AS c
    ON s.code_module = c.code_module
   AND s.code_presentation = c.code_presentation
WHERE c.code_module IS NULL
GROUP BY
    s.code_module,
    s.code_presentation;
    
    SELECT
    SUM(CASE WHEN gender_values > 1 THEN 1 ELSE 0 END)
        AS inconsistent_gender_students,

    SUM(CASE WHEN region_values > 1 THEN 1 ELSE 0 END)
        AS inconsistent_region_students,

    SUM(CASE WHEN education_values > 1 THEN 1 ELSE 0 END)
        AS inconsistent_education_students,

    SUM(CASE WHEN imd_values > 1 THEN 1 ELSE 0 END)
        AS inconsistent_imd_students,

    SUM(CASE WHEN age_values > 1 THEN 1 ELSE 0 END)
        AS inconsistent_age_students,

    SUM(CASE WHEN disability_values > 1 THEN 1 ELSE 0 END)
        AS inconsistent_disability_students

FROM (
    SELECT
        id_student,
        COUNT(DISTINCT TRIM(gender)) AS gender_values,
        COUNT(DISTINCT TRIM(region)) AS region_values,
        COUNT(DISTINCT TRIM(highest_education)) AS education_values,
        COUNT(DISTINCT TRIM(imd_band)) AS imd_values,
        COUNT(DISTINCT TRIM(age_band)) AS age_values,
        COUNT(DISTINCT TRIM(disability)) AS disability_values
    FROM stg_student_info
    GROUP BY id_student
) AS student_consistency;

SELECT
    id_student,
    GROUP_CONCAT(
        DISTINCT age_band
        ORDER BY age_band
        SEPARATOR ', '
    ) AS recorded_age_bands,

    GROUP_CONCAT(
        CONCAT(code_module, '-', code_presentation, ': ', age_band)
        ORDER BY code_presentation
        SEPARATOR ' | '
    ) AS enrolment_history

FROM stg_student_info
GROUP BY id_student
HAVING COUNT(DISTINCT age_band) > 1
LIMIT 20;

SELECT 'gender' AS column_name, gender AS category, COUNT(*) AS frequency
FROM stg_student_info
GROUP BY gender

UNION ALL

SELECT 'age_band', age_band, COUNT(*)
FROM stg_student_info
GROUP BY age_band

UNION ALL

SELECT 'disability', disability, COUNT(*)
FROM stg_student_info
GROUP BY disability

UNION ALL

SELECT 'final_result', final_result, COUNT(*)
FROM stg_student_info
GROUP BY final_result

ORDER BY column_name, category;

SELECT
    COUNT(DISTINCT id_student) AS unique_students,

    MIN(CAST(num_of_prev_attempts AS SIGNED))
        AS minimum_previous_attempts,

    MAX(CAST(num_of_prev_attempts AS SIGNED))
        AS maximum_previous_attempts,

    ROUND(AVG(CAST(num_of_prev_attempts AS SIGNED)), 2)
        AS average_previous_attempts,

    MIN(CAST(studied_credits AS SIGNED))
        AS minimum_studied_credits,

    MAX(CAST(studied_credits AS SIGNED))
        AS maximum_studied_credits,

    ROUND(AVG(CAST(studied_credits AS SIGNED)), 2)
        AS average_studied_credits,

    SUM(
        CASE WHEN CAST(num_of_prev_attempts AS SIGNED) < 0
             THEN 1 ELSE 0 END
    ) AS negative_previous_attempts,

    SUM(
        CASE WHEN CAST(studied_credits AS SIGNED) <= 0
             THEN 1 ELSE 0 END
    ) AS nonpositive_studied_credits

FROM stg_student_info;

SELECT
    CAST(studied_credits AS SIGNED) AS studied_credits,
    COUNT(*) AS number_of_records
FROM stg_student_info
GROUP BY CAST(studied_credits AS SIGNED)
ORDER BY studied_credits DESC
LIMIT 15;



SELECT
    'highest_education' AS column_name,
    highest_education AS category,
    COUNT(*) AS frequency
FROM stg_student_info
GROUP BY highest_education

UNION ALL

SELECT
    'imd_band',
    imd_band,
    COUNT(*)
FROM stg_student_info
GROUP BY imd_band

ORDER BY column_name, category;

SELECT
    region,
    COUNT(*) AS frequency
FROM stg_student_info
GROUP BY region
ORDER BY region;

SELECT COUNT(*) AS total_rows
FROM stg_student_registration;

SELECT *
FROM stg_student_registration
LIMIT 10;


SELECT
    SUM(CASE WHEN code_module IS NULL OR TRIM(code_module) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_code_module,

    SUM(CASE WHEN code_presentation IS NULL
                  OR TRIM(code_presentation) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_code_presentation,

    SUM(CASE WHEN id_student IS NULL OR TRIM(id_student) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_id_student,

    SUM(CASE WHEN date_registration IS NULL
                  OR TRIM(date_registration) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_registration_date,

    SUM(CASE WHEN date_unregistration IS NULL
                  OR TRIM(date_unregistration) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_unregistration_date
FROM stg_student_registration;


SELECT
    si.final_result,
    COUNT(*) AS total_records,

    SUM(
        CASE
            WHEN sr.date_registration IS NULL
              OR TRIM(sr.date_registration) IN ('', '?')
            THEN 1 ELSE 0
        END
    ) AS missing_registration_dates,

    SUM(
        CASE
            WHEN sr.date_unregistration IS NULL
              OR TRIM(sr.date_unregistration) IN ('', '?')
            THEN 1 ELSE 0
        END
    ) AS missing_unregistration_dates,

    SUM(
        CASE
            WHEN sr.date_unregistration IS NOT NULL
             AND TRIM(sr.date_unregistration) NOT IN ('', '?')
            THEN 1 ELSE 0
        END
    ) AS recorded_unregistration_dates

FROM stg_student_registration AS sr
JOIN stg_student_info AS si
    ON sr.id_student = si.id_student
   AND sr.code_module = si.code_module
   AND sr.code_presentation = si.code_presentation

GROUP BY si.final_result
ORDER BY si.final_result;


SELECT
    id_student,
    code_module,
    code_presentation,
    COUNT(*) AS number_of_records
FROM stg_student_registration
GROUP BY
    id_student,
    code_module,
    code_presentation
HAVING COUNT(*) > 1;

SELECT
    (
        SELECT COUNT(*)
        FROM stg_student_registration AS sr
        LEFT JOIN stg_student_info AS si
            ON sr.id_student = si.id_student
           AND sr.code_module = si.code_module
           AND sr.code_presentation = si.code_presentation
        WHERE si.id_student IS NULL
    ) AS registrations_without_student_info,

    (
        SELECT COUNT(*)
        FROM stg_student_info AS si
        LEFT JOIN stg_student_registration AS sr
            ON si.id_student = sr.id_student
           AND si.code_module = sr.code_module
           AND si.code_presentation = sr.code_presentation
        WHERE sr.id_student IS NULL
    ) AS student_info_without_registration;
    
    SELECT
    MIN(
        CASE
            WHEN TRIM(sr.date_registration) NOT IN ('', '?')
            THEN CAST(sr.date_registration AS SIGNED)
        END
    ) AS earliest_registration_day,

    MAX(
        CASE
            WHEN TRIM(sr.date_registration) NOT IN ('', '?')
            THEN CAST(sr.date_registration AS SIGNED)
        END
    ) AS latest_registration_day,

    MIN(
        CASE
            WHEN TRIM(sr.date_unregistration) NOT IN ('', '?')
            THEN CAST(sr.date_unregistration AS SIGNED)
        END
    ) AS earliest_unregistration_day,

    MAX(
        CASE
            WHEN TRIM(sr.date_unregistration) NOT IN ('', '?')
            THEN CAST(sr.date_unregistration AS SIGNED)
        END
    ) AS latest_unregistration_day,

    SUM(
        CASE
            WHEN TRIM(sr.date_registration) NOT IN ('', '?')
             AND TRIM(sr.date_unregistration) NOT IN ('', '?')
             AND CAST(sr.date_unregistration AS SIGNED) <
                 CAST(sr.date_registration AS SIGNED)
            THEN 1 ELSE 0
        END
    ) AS unregistration_before_registration,

    SUM(
        CASE
            WHEN TRIM(sr.date_registration) NOT IN ('', '?')
             AND CAST(sr.date_registration AS SIGNED) >
                 CAST(c.module_presentation_length AS SIGNED)
            THEN 1 ELSE 0
        END
    ) AS registration_after_module_end,

    SUM(
        CASE
            WHEN TRIM(sr.date_unregistration) NOT IN ('', '?')
             AND CAST(sr.date_unregistration AS SIGNED) >
                 CAST(c.module_presentation_length AS SIGNED)
            THEN 1 ELSE 0
        END
    ) AS unregistration_after_module_end

FROM stg_student_registration AS sr
JOIN stg_courses AS c
    ON sr.code_module = c.code_module
   AND sr.code_presentation = c.code_presentation;
   
   SELECT
    sr.id_student,
    sr.code_module,
    sr.code_presentation,
    sr.date_registration,
    sr.date_unregistration,
    c.module_presentation_length,
    si.final_result,

    CAST(sr.date_unregistration AS SIGNED) -
    CAST(c.module_presentation_length AS SIGNED)
        AS days_after_module_end

FROM stg_student_registration AS sr
JOIN stg_courses AS c
    ON sr.code_module = c.code_module
   AND sr.code_presentation = c.code_presentation
JOIN stg_student_info AS si
    ON sr.id_student = si.id_student
   AND sr.code_module = si.code_module
   AND sr.code_presentation = si.code_presentation

WHERE TRIM(sr.date_unregistration) NOT IN ('', '?')
  AND CAST(sr.date_unregistration AS SIGNED) >
      CAST(c.module_presentation_length AS SIGNED);
      
      SELECT
    sr.id_student,
    sr.code_module,
    sr.code_presentation,
    sr.date_registration,
    sr.date_unregistration,
    si.final_result
FROM stg_student_registration AS sr
JOIN stg_student_info AS si
    ON sr.id_student = si.id_student
   AND sr.code_module = si.code_module
   AND sr.code_presentation = si.code_presentation
WHERE TRIM(sr.date_unregistration) NOT IN ('', '?')
ORDER BY CAST(sr.date_unregistration AS SIGNED)
LIMIT 10;


SELECT COUNT(*) AS total_rows
FROM stg_student_assessment;

SELECT *
FROM stg_student_assessment
LIMIT 10;

SELECT
    SUM(CASE WHEN id_assessment IS NULL
                  OR TRIM(id_assessment) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_id_assessment,

    SUM(CASE WHEN id_student IS NULL
                  OR TRIM(id_student) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_id_student,

    SUM(CASE WHEN date_submitted IS NULL
                  OR TRIM(date_submitted) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_date_submitted,

    SUM(CASE WHEN is_banked IS NULL
                  OR TRIM(is_banked) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_is_banked,

    SUM(CASE WHEN score IS NULL
                  OR TRIM(score) IN ('', '?')
        THEN 1 ELSE 0 END) AS missing_score
FROM stg_student_assessment;


SELECT
    id_assessment,
    id_student,
    COUNT(*) AS number_of_records
FROM stg_student_assessment
GROUP BY
    id_assessment,
    id_student
HAVING COUNT(*) > 1;


SELECT
    sa.id_assessment,
    COUNT(*) AS unmatched_records
FROM stg_student_assessment AS sa
LEFT JOIN stg_assessments AS a
    ON sa.id_assessment = a.id_assessment
WHERE a.id_assessment IS NULL
GROUP BY sa.id_assessment;


SELECT
    a.code_module,
    a.code_presentation,
    COUNT(*) AS assessment_results_without_registration
FROM stg_student_assessment AS sa
JOIN stg_assessments AS a
    ON sa.id_assessment = a.id_assessment
LEFT JOIN stg_student_registration AS sr
    ON sa.id_student = sr.id_student
   AND a.code_module = sr.code_module
   AND a.code_presentation = sr.code_presentation
WHERE sr.id_student IS NULL
GROUP BY
    a.code_module,
    a.code_presentation;
    
    SELECT
    MIN(
        CASE
            WHEN TRIM(score) NOT IN ('', '?')
            THEN CAST(score AS SIGNED)
        END
    ) AS minimum_score,

    MAX(
        CASE
            WHEN TRIM(score) NOT IN ('', '?')
            THEN CAST(score AS SIGNED)
        END
    ) AS maximum_score,

    SUM(
        CASE
            WHEN TRIM(score) NOT IN ('', '?')
             AND (CAST(score AS SIGNED) < 0
               OR CAST(score AS SIGNED) > 100)
            THEN 1 ELSE 0
        END
    ) AS scores_outside_0_to_100,

    MIN(CAST(date_submitted AS SIGNED))
        AS earliest_submission_day,

    MAX(CAST(date_submitted AS SIGNED))
        AS latest_submission_day,

    SUM(
        CASE
            WHEN CAST(date_submitted AS SIGNED) < 0
            THEN 1 ELSE 0
        END
    ) AS submissions_before_module_start,

    SUM(
        CASE
            WHEN TRIM(is_banked) NOT IN ('0', '1')
            THEN 1 ELSE 0
        END
    ) AS invalid_banked_values

FROM stg_student_assessment;


SELECT
    is_banked,
    COUNT(*) AS early_submissions,
    MIN(CAST(date_submitted AS SIGNED))
        AS earliest_submission_day,
    MAX(CAST(date_submitted AS SIGNED))
        AS latest_early_submission_day
FROM stg_student_assessment
WHERE CAST(date_submitted AS SIGNED) < 0
GROUP BY is_banked;

SELECT
    COUNT(*) AS submissions_after_module_end,

    MAX(
        CAST(sa.date_submitted AS SIGNED) -
        CAST(c.module_presentation_length AS SIGNED)
    ) AS maximum_days_after_end

FROM stg_student_assessment AS sa
JOIN stg_assessments AS a
    ON sa.id_assessment = a.id_assessment
JOIN stg_courses AS c
    ON a.code_module = c.code_module
   AND a.code_presentation = c.code_presentation

WHERE CAST(sa.date_submitted AS SIGNED) >
      CAST(c.module_presentation_length AS SIGNED);
      
      SELECT
    sa.id_student,
    sa.id_assessment,
    a.code_module,
    a.code_presentation,
    a.assessment_type,
    sa.date_submitted,
    c.module_presentation_length,

    CAST(sa.date_submitted AS SIGNED) -
    CAST(c.module_presentation_length AS SIGNED)
        AS days_after_module_end,

    sa.is_banked,
    sa.score

FROM stg_student_assessment AS sa
JOIN stg_assessments AS a
    ON sa.id_assessment = a.id_assessment
JOIN stg_courses AS c
    ON a.code_module = c.code_module
   AND a.code_presentation = c.code_presentation

WHERE CAST(sa.date_submitted AS SIGNED) >
      CAST(c.module_presentation_length AS SIGNED)

ORDER BY days_after_module_end DESC
LIMIT 10;


SELECT
    a.code_module,
    a.code_presentation,
    a.assessment_type,
    COUNT(*) AS late_submission_records,

    MAX(
        CAST(sa.date_submitted AS SIGNED) -
        CAST(c.module_presentation_length AS SIGNED)
    ) AS maximum_days_after_end

FROM stg_student_assessment AS sa
JOIN stg_assessments AS a
    ON sa.id_assessment = a.id_assessment
JOIN stg_courses AS c
    ON a.code_module = c.code_module
   AND a.code_presentation = c.code_presentation


SELECT COUNT(*) AS total_rows
FROM stg_student_vle;
WHERE CAST(sa.date_submitted AS SIGNED) >
      CAST(c.module_presentation_length AS SIGNED)

GROUP BY
    a.code_module,
    a.code_presentation,
    a.assessment_type

ORDER BY late_submission_records DESC;

SELECT COUNT(*) AS total_rows
FROM stg_student_vle;

SELECT COUNT(*) AS total_rows

SELECT
    SUM(CASE
        WHEN code_module IS NULL OR TRIM(code_module) IN ('', '?')
        THEN 1 ELSE 0
    END) AS missing_code_module,

    SUM(CASE
        WHEN code_presentation IS NULL
          OR TRIM(code_presentation) IN ('', '?')
        THEN 1 ELSE 0
    END) AS missing_code_presentation,

    SUM(CASE
        WHEN id_student IS NULL OR TRIM(id_student) IN ('', '?')
        THEN 1 ELSE 0
    END) AS missing_id_student,

    SUM(CASE
        WHEN id_site IS NULL OR TRIM(id_site) IN ('', '?')
        THEN 1 ELSE 0
    END) AS missing_id_site,

    SUM(CASE
        WHEN `date` IS NULL OR TRIM(`date`) IN ('', '?')
        THEN 1 ELSE 0
    END) AS missing_date,

    SUM(CASE
        WHEN sum_click IS NULL OR TRIM(sum_click) IN ('', '?')
        THEN 1 ELSE 0
    END) AS missing_sum_click
FROM stg_student_vle;
FROM oulad_db.stg_student_vle;


SELECT
    COUNT(*) AS actual_rows,
    10655280 AS expected_rows,
    COUNT(*) - 10655280 AS difference
FROM stg_student_vle;

SELECT
    code_module,
    code_presentation,
    id_student,
    id_site,
    `date`,
    COUNT(*) AS number_of_records
FROM stg_student_vle
GROUP BY
    code_module,
    code_presentation,
    id_student,
    id_site,
    `date`
HAVING COUNT(*) > 1
LIMIT 20;


ALTER TABLE oulad_db.stg_student_vle
ADD INDEX idx_stg_vle_duplicate_check (
    code_module,
    code_presentation,
    id_student,
    id_site,
    `date`
);


SHOW INDEX
FROM oulad_db.stg_student_vle
WHERE Key_name = 'idx_stg_vle_duplicate_check';

SELECT
    ID,
    COMMAND,
    TIME,
    STATE,
    LEFT(INFO, 200) AS current_sql
FROM information_schema.PROCESSLIST
WHERE INFO LIKE '%idx_stg_vle_duplicate_check%';


SELECT
    ID,
    TIME,
    STATE,
    LEFT(INFO, 200) AS current_sql
FROM information_schema.PROCESSLIST
WHERE ID = 22;