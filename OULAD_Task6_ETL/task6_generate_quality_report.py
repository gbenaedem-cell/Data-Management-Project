"""Run OULAD Task 6 data-quality checks and generate report artifacts.

Outputs:
  output/data_quality_report.csv
  output/data_quality_summary.md
  output/pipeline_run_log.csv

The same check results are also stored in oulad_etl.data_quality_results.
"""

from __future__ import annotations

import csv
import os
import sys
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine, URL


@dataclass(frozen=True)
class QualityResult:
    layer: str
    table_name: str
    check_name: str
    observed_value: str
    expectation: str
    status: str
    interpretation: str


def required_environment(name: str) -> str:
    value = os.getenv(name)
    if value is None or value == "":
        raise RuntimeError(f"Missing required .env setting: {name}")
    return value


def build_engine() -> Engine:
    load_dotenv()
    database = required_environment("MYSQL_DATABASE")
    if database != "oulad_etl":
        raise RuntimeError(
            "Safety stop: MYSQL_DATABASE must be oulad_etl for Task 6."
        )
    url = URL.create(
        drivername="mysql+pymysql",
        username=required_environment("MYSQL_USER"),
        password=os.getenv("MYSQL_PASSWORD", ""),
        host=os.getenv("MYSQL_HOST", "127.0.0.1"),
        port=int(os.getenv("MYSQL_PORT", "3306")),
        database=database,
    )
    return create_engine(
        url,
        pool_pre_ping=True,
        connect_args={
            "connect_timeout": 30,
            "read_timeout": 7200,
            "write_timeout": 7200,
        },
    )


def query_value(engine: Engine, sql: str) -> Any:
    with engine.connect() as connection:
        return connection.execute(text(sql)).scalar_one()


def integer_value(engine: Engine, sql: str) -> int:
    value = query_value(engine, sql)
    return int(value or 0)


def exact_check(
    results: list[QualityResult],
    engine: Engine,
    layer: str,
    table_name: str,
    check_name: str,
    sql: str,
    expected: int,
    interpretation: str,
) -> None:
    observed = integer_value(engine, sql)
    results.append(
        QualityResult(
            layer=layer,
            table_name=table_name,
            check_name=check_name,
            observed_value=f"{observed}",
            expectation=f"Exactly {expected}",
            status="PASS" if observed == expected else "FAIL",
            interpretation=interpretation,
        )
    )


def informational_check(
    results: list[QualityResult],
    engine: Engine,
    layer: str,
    table_name: str,
    check_name: str,
    sql: str,
    interpretation: str,
) -> None:
    observed = integer_value(engine, sql)
    results.append(
        QualityResult(
            layer=layer,
            table_name=table_name,
            check_name=check_name,
            observed_value=f"{observed}",
            expectation="Documented source characteristic",
            status="INFO",
            interpretation=interpretation,
        )
    )


def collect_quality_results(engine: Engine) -> list[QualityResult]:
    results: list[QualityResult] = []

    staging_counts = {
        "stg_courses": 22,
        "stg_assessments": 206,
        "stg_vle": 6_364,
        "stg_student_info": 32_593,
        "stg_student_registration": 32_593,
        "stg_student_assessment": 173_912,
        "stg_student_vle": 10_655_280,
    }
    for table, expected in staging_counts.items():
        exact_check(
            results,
            engine,
            "staging",
            table,
            "source row-count reconciliation",
            f"SELECT COUNT(*) FROM `{table}`",
            expected,
            "The staging table contains the same number of rows as its raw CSV.",
        )

    exact_check(
        results,
        engine,
        "staging",
        "stg_courses",
        "missing required course values",
        """
        SELECT COUNT(*) FROM stg_courses
        WHERE TRIM(code_module) IN ('', '?')
           OR TRIM(code_presentation) IN ('', '?')
           OR TRIM(module_presentation_length) IN ('', '?')
        """,
        0,
        "Every course record has its business key and presentation length.",
    )
    exact_check(
        results,
        engine,
        "staging",
        "stg_assessments",
        "duplicate assessment identifiers",
        """
        SELECT COUNT(*) FROM (
            SELECT id_assessment
            FROM stg_assessments
            GROUP BY id_assessment
            HAVING COUNT(*) > 1
        ) AS duplicates
        """,
        0,
        "Assessment identifiers are unique in the raw data.",
    )
    informational_check(
        results,
        engine,
        "staging",
        "stg_assessments",
        "missing assessment dates",
        """
        SELECT COUNT(*) FROM stg_assessments
        WHERE TRIM(`date`) IN ('', '?')
        """,
        "Eleven Exam records have no scheduled date; these become SQL NULL.",
    )
    informational_check(
        results,
        engine,
        "staging",
        "stg_vle",
        "resources with both week fields missing",
        """
        SELECT COUNT(*) FROM stg_vle
        WHERE TRIM(week_from) IN ('', '?')
          AND TRIM(week_to) IN ('', '?')
        """,
        "Missing resource-week ranges are retained as SQL NULL pairs.",
    )
    exact_check(
        results,
        engine,
        "staging",
        "stg_vle",
        "incomplete or reversed resource-week pairs",
        """
        SELECT COUNT(*) FROM stg_vle
        WHERE (
            TRIM(week_from) IN ('', '?')
            AND TRIM(week_to) NOT IN ('', '?')
        ) OR (
            TRIM(week_from) NOT IN ('', '?')
            AND TRIM(week_to) IN ('', '?')
        ) OR (
            TRIM(week_from) NOT IN ('', '?')
            AND TRIM(week_to) NOT IN ('', '?')
            AND CAST(TRIM(week_to) AS SIGNED)
                < CAST(TRIM(week_from) AS SIGNED)
        )
        """,
        0,
        "No VLE resource has only one week value or a reversed week range.",
    )
    informational_check(
        results,
        engine,
        "staging",
        "stg_student_info",
        "missing IMD-band values",
        """
        SELECT COUNT(*) FROM stg_student_info
        WHERE TRIM(imd_band) IN ('', '?')
        """,
        "Unknown IMD bands are standardised to SQL NULL in the cleaned layer.",
    )
    informational_check(
        results,
        engine,
        "staging",
        "stg_student_info",
        "nonstandard 10-20 IMD labels",
        """
        SELECT COUNT(*) FROM stg_student_info
        WHERE TRIM(imd_band) = '10-20'
        """,
        "The nonstandard label is transformed to 10-20%.",
    )
    informational_check(
        results,
        engine,
        "staging",
        "stg_student_registration",
        "missing registration dates",
        """
        SELECT COUNT(*) FROM stg_student_registration
        WHERE TRIM(date_registration) IN ('', '?')
        """,
        "Missing registration dates are retained as SQL NULL.",
    )
    informational_check(
        results,
        engine,
        "staging",
        "stg_student_registration",
        "missing unregistration dates",
        """
        SELECT COUNT(*) FROM stg_student_registration
        WHERE TRIM(date_unregistration) IN ('', '?')
        """,
        "A missing unregistration date normally means no withdrawal was recorded.",
    )
    informational_check(
        results,
        engine,
        "staging",
        "stg_student_assessment",
        "missing assessment scores",
        """
        SELECT COUNT(*) FROM stg_student_assessment
        WHERE TRIM(score) IN ('', '?')
        """,
        "Missing scores are retained as SQL NULL rather than treated as zero.",
    )
    exact_check(
        results,
        engine,
        "staging",
        "stg_student_vle",
        "missing required interaction values",
        """
        SELECT COUNT(*) FROM stg_student_vle
        WHERE TRIM(code_module) IN ('', '?')
           OR TRIM(code_presentation) IN ('', '?')
           OR TRIM(id_student) IN ('', '?')
           OR TRIM(id_site) IN ('', '?')
           OR TRIM(`date`) IN ('', '?')
           OR TRIM(sum_click) IN ('', '?')
        """,
        0,
        "All interaction business keys and click totals are present.",
    )

    clean_counts = {
        "clean_module_presentation": 22,
        "clean_student": 28_785,
        "clean_registration": 32_593,
        "clean_assessment": 206,
        "clean_vle_resource": 6_364,
        "clean_student_assessment": 173_912,
        "clean_student_vle_interaction": 8_459_320,
    }
    for table, expected in clean_counts.items():
        exact_check(
            results,
            engine,
            "clean",
            table,
            "cleaned row-count reconciliation",
            f"SELECT COUNT(*) FROM `{table}`",
            expected,
            "The cleaned relation has the expected documented grain.",
        )

    exact_check(
        results,
        engine,
        "clean",
        "clean_student",
        "unstandardised IMD labels remaining",
        "SELECT COUNT(*) FROM clean_student WHERE imd_band = '10-20'",
        0,
        "All 10-20 values were standardised to 10-20%.",
    )
    exact_check(
        results,
        engine,
        "clean",
        "clean_registration",
        "unregistration before registration",
        """
        SELECT COUNT(*) FROM clean_registration
        WHERE date_registration IS NOT NULL
          AND date_unregistration IS NOT NULL
          AND date_unregistration < date_registration
        """,
        0,
        "Registration dates follow a valid chronological order.",
    )
    exact_check(
        results,
        engine,
        "clean",
        "clean_student_assessment",
        "scores outside 0 to 100",
        """
        SELECT COUNT(*) FROM clean_student_assessment
        WHERE score IS NOT NULL AND score NOT BETWEEN 0 AND 100
        """,
        0,
        "All recorded assessment scores are in the permitted range.",
    )
    exact_check(
        results,
        engine,
        "clean",
        "clean_student_vle_interaction",
        "repeated daily-grain rows consolidated",
        """
        SELECT
            (SELECT COUNT(*) FROM stg_student_vle)
            -
            (SELECT COUNT(*) FROM clean_student_vle_interaction)
        """,
        2_195_960,
        "Repeated student-resource-day rows were consolidated by summing clicks.",
    )
    exact_check(
        results,
        engine,
        "clean",
        "clean_student_vle_interaction",
        "nonpositive click totals",
        """
        SELECT COUNT(*) FROM clean_student_vle_interaction
        WHERE sum_click <= 0
        """,
        0,
        "Every cleaned daily interaction has a positive click total.",
    )
    exact_check(
        results,
        engine,
        "clean",
        "clean_student_vle_interaction",
        "interactions without registration",
        """
        SELECT COUNT(*)
        FROM clean_student_vle_interaction AS i
        LEFT JOIN clean_registration AS r
          ON r.id_student = i.id_student
         AND r.code_module = i.code_module
         AND r.code_presentation = i.code_presentation
        WHERE r.id_student IS NULL
        """,
        0,
        "Every interaction matches an existing student registration.",
    )
    exact_check(
        results,
        engine,
        "clean",
        "clean_student_vle_interaction",
        "interactions without contextual resource",
        """
        SELECT COUNT(*)
        FROM clean_student_vle_interaction AS i
        LEFT JOIN clean_vle_resource AS v
          ON v.id_site = i.id_site
         AND v.code_module = i.code_module
         AND v.code_presentation = i.code_presentation
        WHERE v.id_site IS NULL
        """,
        0,
        "Every interaction matches a VLE resource in the same presentation.",
    )

    analytics_counts = {
        "analytics_student_engagement": 32_593,
        "analytics_completion_by_presentation": 22,
        "analytics_assessment_performance": 57,
        "analytics_engagement_by_result": 4,
    }
    for table, expected in analytics_counts.items():
        exact_check(
            results,
            engine,
            "analytics",
            table,
            "analytics row-count reconciliation",
            f"SELECT COUNT(*) FROM `{table}`",
            expected,
            "The analytics table has the expected reporting grain.",
        )

    exact_check(
        results,
        engine,
        "analytics",
        "analytics_completion_by_presentation",
        "registrations represented in presentation summaries",
        """
        SELECT SUM(registered_students)
        FROM analytics_completion_by_presentation
        """,
        32_593,
        "Every cleaned registration is represented in the completion summary.",
    )
    exact_check(
        results,
        engine,
        "analytics",
        "analytics_engagement_by_result",
        "registrations represented in outcome summaries",
        "SELECT SUM(registrations) FROM analytics_engagement_by_result",
        32_593,
        "Every cleaned registration is represented in an outcome group.",
    )

    return results


def save_results_to_mysql(engine: Engine, results: list[QualityResult]) -> None:
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS data_quality_results (
                    result_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                    layer_name VARCHAR(30) NOT NULL,
                    table_name VARCHAR(64) NOT NULL,
                    check_name VARCHAR(150) NOT NULL,
                    observed_value VARCHAR(100) NOT NULL,
                    expectation VARCHAR(150) NOT NULL,
                    status VARCHAR(10) NOT NULL,
                    interpretation VARCHAR(500) NOT NULL,
                    generated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (result_id),
                    INDEX idx_quality_status (status, layer_name)
                ) ENGINE=InnoDB
                """
            )
        )
        connection.execute(text("TRUNCATE TABLE data_quality_results"))
        connection.execute(
            text(
                """
                INSERT INTO data_quality_results (
                    layer_name,
                    table_name,
                    check_name,
                    observed_value,
                    expectation,
                    status,
                    interpretation
                ) VALUES (
                    :layer,
                    :table_name,
                    :check_name,
                    :observed_value,
                    :expectation,
                    :status,
                    :interpretation
                )
                """
            ),
            [asdict(result) for result in results],
        )


def write_csv_report(output_dir: Path, results: list[QualityResult]) -> Path:
    output_path = output_dir / "data_quality_report.csv"
    fieldnames = list(asdict(results[0]).keys())
    with output_path.open("w", encoding="utf-8-sig", newline="") as output_file:
        writer = csv.DictWriter(output_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(asdict(result) for result in results)
    return output_path


def markdown_cell(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def write_markdown_report(
    output_dir: Path, results: list[QualityResult]
) -> Path:
    output_path = output_dir / "data_quality_summary.md"
    passed = sum(result.status == "PASS" for result in results)
    failed = sum(result.status == "FAIL" for result in results)
    informational = sum(result.status == "INFO" for result in results)
    overall = "PASS" if failed == 0 else "FAIL"
    generated = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")

    lines = [
        "# OULAD Task 6 Data-Quality Report",
        "",
        f"Generated: {generated}",
        "",
        "## Overall result",
        "",
        f"**{overall}** — {passed} checks passed, {failed} failed, and "
        f"{informational} documented source characteristics were recorded.",
        "",
        "The pipeline reconciled all seven CSV files with their staging "
        "tables, transformed raw text into constrained cleaned relations, "
        "consolidated repeated student-resource-day interactions, and "
        "validated the reporting layer.",
        "",
        "## Important quality findings and treatments",
        "",
        "- Unknown markers (`?`) were converted to SQL `NULL` only where "
        "missing values are semantically permitted.",
        "- The inconsistent IMD label `10-20` was standardised to `10-20%`.",
        "- Missing assessment scores were kept as `NULL`, not converted to zero.",
        "- Repeated VLE rows at the student-resource-day grain were "
        "consolidated by summing `sum_click`.",
        "- Primary keys, foreign keys and check constraints protect the "
        "cleaned layer.",
        "- Analytics totals reconcile to all 32,593 registrations.",
        "",
        "## Detailed checks",
        "",
        "| Layer | Table | Check | Observed | Expectation | Status | Interpretation |",
        "|---|---|---|---:|---|---|---|",
    ]
    for result in results:
        lines.append(
            "| "
            + " | ".join(
                markdown_cell(value)
                for value in (
                    result.layer,
                    result.table_name,
                    result.check_name,
                    result.observed_value,
                    result.expectation,
                    result.status,
                    result.interpretation,
                )
            )
            + " |"
        )
    lines.append("")
    output_path.write_text("\n".join(lines), encoding="utf-8")
    return output_path


def write_pipeline_log(engine: Engine, output_dir: Path) -> Path:
    output_path = output_dir / "pipeline_run_log.csv"
    with engine.connect() as connection:
        rows = connection.execute(
            text(
                """
                SELECT
                    log_id,
                    pipeline_stage,
                    source_file,
                    target_table,
                    row_count,
                    duration_seconds,
                    status,
                    message,
                    logged_at
                FROM etl_run_log
                ORDER BY log_id
                """
            )
        ).mappings()
        fieldnames = [
            "log_id",
            "pipeline_stage",
            "source_file",
            "target_table",
            "row_count",
            "duration_seconds",
            "status",
            "message",
            "logged_at",
        ]
        with output_path.open(
            "w", encoding="utf-8-sig", newline=""
        ) as output_file:
            writer = csv.DictWriter(output_file, fieldnames=fieldnames)
            writer.writeheader()
            for row in rows:
                writer.writerow(dict(row))
    return output_path


def main() -> int:
    try:
        engine = build_engine()
        output_dir = Path("output")
        output_dir.mkdir(parents=True, exist_ok=True)

        print("Running Task 6 data-quality checks ...", flush=True)
        results = collect_quality_results(engine)
        save_results_to_mysql(engine, results)
        csv_path = write_csv_report(output_dir, results)
        markdown_path = write_markdown_report(output_dir, results)
        log_path = write_pipeline_log(engine, output_dir)

        passed = sum(result.status == "PASS" for result in results)
        failed = sum(result.status == "FAIL" for result in results)
        informational = sum(result.status == "INFO" for result in results)

        print(f"\nChecks passed: {passed}")
        print(f"Checks failed: {failed}")
        print(f"Documented source characteristics: {informational}")
        print(f"\nCreated: {csv_path}")
        print(f"Created: {markdown_path}")
        print(f"Created: {log_path}")
        print("Stored results in: oulad_etl.data_quality_results")

        if failed:
            print("\nData-quality report completed with failures.")
            return 1
        print("\nData-quality report completed successfully.")
        return 0
    except Exception as error:
        print(f"\nDATA-QUALITY REPORT FAILED: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
