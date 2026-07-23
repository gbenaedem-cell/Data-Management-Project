# OULAD Task 6 Data-Quality Report

Generated: 2026-07-21 16:16:14 Greenwich Standard Time

## Overall result

**PASS** — 31 checks passed, 0 failed, and 7 documented source characteristics were recorded.

The pipeline reconciled all seven CSV files with their staging tables, transformed raw text into constrained cleaned relations, consolidated repeated student-resource-day interactions, and validated the reporting layer.

## Important quality findings and treatments

- Unknown markers (`?`) were converted to SQL `NULL` only where missing values are semantically permitted.
- The inconsistent IMD label `10-20` was standardised to `10-20%`.
- Missing assessment scores were kept as `NULL`, not converted to zero.
- Repeated VLE rows at the student-resource-day grain were consolidated by summing `sum_click`.
- Primary keys, foreign keys and check constraints protect the cleaned layer.
- Analytics totals reconcile to all 32,593 registrations.

## Detailed checks

| Layer | Table | Check | Observed | Expectation | Status | Interpretation |
|---|---|---|---:|---|---|---|
| staging | stg_courses | source row-count reconciliation | 22 | Exactly 22 | PASS | The staging table contains the same number of rows as its raw CSV. |
| staging | stg_assessments | source row-count reconciliation | 206 | Exactly 206 | PASS | The staging table contains the same number of rows as its raw CSV. |
| staging | stg_vle | source row-count reconciliation | 6364 | Exactly 6364 | PASS | The staging table contains the same number of rows as its raw CSV. |
| staging | stg_student_info | source row-count reconciliation | 32593 | Exactly 32593 | PASS | The staging table contains the same number of rows as its raw CSV. |
| staging | stg_student_registration | source row-count reconciliation | 32593 | Exactly 32593 | PASS | The staging table contains the same number of rows as its raw CSV. |
| staging | stg_student_assessment | source row-count reconciliation | 173912 | Exactly 173912 | PASS | The staging table contains the same number of rows as its raw CSV. |
| staging | stg_student_vle | source row-count reconciliation | 10655280 | Exactly 10655280 | PASS | The staging table contains the same number of rows as its raw CSV. |
| staging | stg_courses | missing required course values | 0 | Exactly 0 | PASS | Every course record has its business key and presentation length. |
| staging | stg_assessments | duplicate assessment identifiers | 0 | Exactly 0 | PASS | Assessment identifiers are unique in the raw data. |
| staging | stg_assessments | missing assessment dates | 11 | Documented source characteristic | INFO | Eleven Exam records have no scheduled date; these become SQL NULL. |
| staging | stg_vle | resources with both week fields missing | 5243 | Documented source characteristic | INFO | Missing resource-week ranges are retained as SQL NULL pairs. |
| staging | stg_vle | incomplete or reversed resource-week pairs | 0 | Exactly 0 | PASS | No VLE resource has only one week value or a reversed week range. |
| staging | stg_student_info | missing IMD-band values | 1111 | Documented source characteristic | INFO | Unknown IMD bands are standardised to SQL NULL in the cleaned layer. |
| staging | stg_student_info | nonstandard 10-20 IMD labels | 3516 | Documented source characteristic | INFO | The nonstandard label is transformed to 10-20%. |
| staging | stg_student_registration | missing registration dates | 45 | Documented source characteristic | INFO | Missing registration dates are retained as SQL NULL. |
| staging | stg_student_registration | missing unregistration dates | 22521 | Documented source characteristic | INFO | A missing unregistration date normally means no withdrawal was recorded. |
| staging | stg_student_assessment | missing assessment scores | 173 | Documented source characteristic | INFO | Missing scores are retained as SQL NULL rather than treated as zero. |
| staging | stg_student_vle | missing required interaction values | 0 | Exactly 0 | PASS | All interaction business keys and click totals are present. |
| clean | clean_module_presentation | cleaned row-count reconciliation | 22 | Exactly 22 | PASS | The cleaned relation has the expected documented grain. |
| clean | clean_student | cleaned row-count reconciliation | 28785 | Exactly 28785 | PASS | The cleaned relation has the expected documented grain. |
| clean | clean_registration | cleaned row-count reconciliation | 32593 | Exactly 32593 | PASS | The cleaned relation has the expected documented grain. |
| clean | clean_assessment | cleaned row-count reconciliation | 206 | Exactly 206 | PASS | The cleaned relation has the expected documented grain. |
| clean | clean_vle_resource | cleaned row-count reconciliation | 6364 | Exactly 6364 | PASS | The cleaned relation has the expected documented grain. |
| clean | clean_student_assessment | cleaned row-count reconciliation | 173912 | Exactly 173912 | PASS | The cleaned relation has the expected documented grain. |
| clean | clean_student_vle_interaction | cleaned row-count reconciliation | 8459320 | Exactly 8459320 | PASS | The cleaned relation has the expected documented grain. |
| clean | clean_student | unstandardised IMD labels remaining | 0 | Exactly 0 | PASS | All 10-20 values were standardised to 10-20%. |
| clean | clean_registration | unregistration before registration | 0 | Exactly 0 | PASS | Registration dates follow a valid chronological order. |
| clean | clean_student_assessment | scores outside 0 to 100 | 0 | Exactly 0 | PASS | All recorded assessment scores are in the permitted range. |
| clean | clean_student_vle_interaction | repeated daily-grain rows consolidated | 2195960 | Exactly 2195960 | PASS | Repeated student-resource-day rows were consolidated by summing clicks. |
| clean | clean_student_vle_interaction | nonpositive click totals | 0 | Exactly 0 | PASS | Every cleaned daily interaction has a positive click total. |
| clean | clean_student_vle_interaction | interactions without registration | 0 | Exactly 0 | PASS | Every interaction matches an existing student registration. |
| clean | clean_student_vle_interaction | interactions without contextual resource | 0 | Exactly 0 | PASS | Every interaction matches a VLE resource in the same presentation. |
| analytics | analytics_student_engagement | analytics row-count reconciliation | 32593 | Exactly 32593 | PASS | The analytics table has the expected reporting grain. |
| analytics | analytics_completion_by_presentation | analytics row-count reconciliation | 22 | Exactly 22 | PASS | The analytics table has the expected reporting grain. |
| analytics | analytics_assessment_performance | analytics row-count reconciliation | 57 | Exactly 57 | PASS | The analytics table has the expected reporting grain. |
| analytics | analytics_engagement_by_result | analytics row-count reconciliation | 4 | Exactly 4 | PASS | The analytics table has the expected reporting grain. |
| analytics | analytics_completion_by_presentation | registrations represented in presentation summaries | 32593 | Exactly 32593 | PASS | Every cleaned registration is represented in the completion summary. |
| analytics | analytics_engagement_by_result | registrations represented in outcome summaries | 32593 | Exactly 32593 | PASS | Every cleaned registration is represented in an outcome group. |
