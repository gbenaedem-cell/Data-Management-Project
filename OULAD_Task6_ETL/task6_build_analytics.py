"""Build the OULAD Task 6 analytics layer from cleaned relational tables.

The script creates reusable, presentation-level, assessment-level, and
registration-level analytical summaries in the oulad_etl schema.  It reads
only clean_* tables and never touches the completed oulad_db schema.
"""

from __future__ import annotations

import os
import sys
import time
from dataclasses import dataclass

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine, URL


@dataclass(frozen=True)
class AnalyticsBuild:
    table: str
    expected_rows: int
    sql: str


EXPECTED_CLEAN_COUNTS = {
    "clean_module_presentation": 22,
    "clean_student": 28_785,
    "clean_registration": 32_593,
    "clean_assessment": 206,
    "clean_vle_resource": 6_364,
    "clean_student_assessment": 173_912,
    "clean_student_vle_interaction": 8_459_320,
}


ANALYTICS_DDL = (
    """
    CREATE TABLE analytics_student_engagement (
        id_student INT NOT NULL,
        code_module VARCHAR(5) NOT NULL,
        code_presentation VARCHAR(5) NOT NULL,
        final_result VARCHAR(20) NOT NULL,
        total_clicks BIGINT NOT NULL,
        active_days INT NOT NULL,
        resources_used INT NOT NULL,
        assessment_submissions INT NOT NULL,
        average_score DECIMAL(5,2),
        CONSTRAINT pk_analytics_student_engagement
            PRIMARY KEY (id_student, code_module, code_presentation),
        CONSTRAINT chk_analytics_student_clicks CHECK (total_clicks >= 0),
        CONSTRAINT chk_analytics_student_days CHECK (active_days >= 0),
        CONSTRAINT chk_analytics_student_resources CHECK (resources_used >= 0),
        CONSTRAINT chk_analytics_student_submissions
            CHECK (assessment_submissions >= 0),
        CONSTRAINT chk_analytics_student_score
            CHECK (average_score IS NULL OR average_score BETWEEN 0 AND 100),
        INDEX idx_analytics_student_result (final_result)
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE analytics_completion_by_presentation (
        code_module VARCHAR(5) NOT NULL,
        code_presentation VARCHAR(5) NOT NULL,
        registered_students INT NOT NULL,
        distinctions INT NOT NULL,
        passes INT NOT NULL,
        failures INT NOT NULL,
        withdrawals INT NOT NULL,
        successful_completion_rate_pct DECIMAL(5,2) NOT NULL,
        CONSTRAINT pk_analytics_completion
            PRIMARY KEY (code_module, code_presentation),
        CONSTRAINT chk_analytics_completion_rate CHECK (
            successful_completion_rate_pct BETWEEN 0 AND 100
        )
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE analytics_assessment_performance (
        code_module VARCHAR(5) NOT NULL,
        code_presentation VARCHAR(5) NOT NULL,
        assessment_type VARCHAR(10) NOT NULL,
        submissions INT NOT NULL,
        missing_scores INT NOT NULL,
        average_score DECIMAL(5,2),
        banked_result_rate_pct DECIMAL(5,2),
        CONSTRAINT pk_analytics_assessment
            PRIMARY KEY (
                code_module, code_presentation, assessment_type
            ),
        CONSTRAINT chk_analytics_assessment_average CHECK (
            average_score IS NULL OR average_score BETWEEN 0 AND 100
        ),
        CONSTRAINT chk_analytics_banked_rate CHECK (
            banked_result_rate_pct IS NULL
            OR banked_result_rate_pct BETWEEN 0 AND 100
        )
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE analytics_engagement_by_result (
        final_result VARCHAR(20) NOT NULL,
        registrations INT NOT NULL,
        average_total_clicks DECIMAL(12,2) NOT NULL,
        average_active_days DECIMAL(8,2) NOT NULL,
        average_resources_used DECIMAL(8,2) NOT NULL,
        average_assessment_submissions DECIMAL(8,2) NOT NULL,
        average_score DECIMAL(5,2),
        CONSTRAINT pk_analytics_engagement_result PRIMARY KEY (final_result)
    ) ENGINE=InnoDB
    """,
)


ANALYTICS_BUILDS = (
    AnalyticsBuild(
        "analytics_student_engagement",
        32_593,
        """
        INSERT INTO analytics_student_engagement (
            id_student,
            code_module,
            code_presentation,
            final_result,
            total_clicks,
            active_days,
            resources_used,
            assessment_submissions,
            average_score
        )
        SELECT
            r.id_student,
            r.code_module,
            r.code_presentation,
            r.final_result,
            COALESCE(v.total_clicks, 0),
            COALESCE(v.active_days, 0),
            COALESCE(v.resources_used, 0),
            COALESCE(a.assessment_submissions, 0),
            a.average_score
        FROM clean_registration AS r
        LEFT JOIN (
            SELECT
                id_student,
                code_module,
                code_presentation,
                SUM(sum_click) AS total_clicks,
                COUNT(DISTINCT interaction_date) AS active_days,
                COUNT(DISTINCT id_site) AS resources_used
            FROM clean_student_vle_interaction
            GROUP BY id_student, code_module, code_presentation
        ) AS v
          ON v.id_student = r.id_student
         AND v.code_module = r.code_module
         AND v.code_presentation = r.code_presentation
        LEFT JOIN (
            SELECT
                id_student,
                code_module,
                code_presentation,
                COUNT(*) AS assessment_submissions,
                ROUND(AVG(score), 2) AS average_score
            FROM clean_student_assessment
            GROUP BY id_student, code_module, code_presentation
        ) AS a
          ON a.id_student = r.id_student
         AND a.code_module = r.code_module
         AND a.code_presentation = r.code_presentation
        """,
    ),
    AnalyticsBuild(
        "analytics_completion_by_presentation",
        22,
        """
        INSERT INTO analytics_completion_by_presentation (
            code_module,
            code_presentation,
            registered_students,
            distinctions,
            passes,
            failures,
            withdrawals,
            successful_completion_rate_pct
        )
        SELECT
            code_module,
            code_presentation,
            COUNT(*),
            SUM(final_result = 'Distinction'),
            SUM(final_result = 'Pass'),
            SUM(final_result = 'Fail'),
            SUM(final_result = 'Withdrawn'),
            ROUND(
                100.0 * SUM(final_result IN ('Pass', 'Distinction')) / COUNT(*),
                2
            )
        FROM clean_registration
        GROUP BY code_module, code_presentation
        """,
    ),
    AnalyticsBuild(
        "analytics_assessment_performance",
        57,
        """
        INSERT INTO analytics_assessment_performance (
            code_module,
            code_presentation,
            assessment_type,
            submissions,
            missing_scores,
            average_score,
            banked_result_rate_pct
        )
        SELECT
            a.code_module,
            a.code_presentation,
            a.assessment_type,
            COUNT(sa.id_student),
            SUM(
                CASE
                    WHEN sa.id_student IS NOT NULL AND sa.score IS NULL THEN 1
                    ELSE 0
                END
            ),
            ROUND(AVG(sa.score), 2),
            ROUND(100.0 * AVG(sa.is_banked), 2)
        FROM clean_assessment AS a
        LEFT JOIN clean_student_assessment AS sa
          ON sa.id_assessment = a.id_assessment
        GROUP BY a.code_module, a.code_presentation, a.assessment_type
        """,
    ),
    AnalyticsBuild(
        "analytics_engagement_by_result",
        4,
        """
        INSERT INTO analytics_engagement_by_result (
            final_result,
            registrations,
            average_total_clicks,
            average_active_days,
            average_resources_used,
            average_assessment_submissions,
            average_score
        )
        SELECT
            final_result,
            COUNT(*),
            ROUND(AVG(total_clicks), 2),
            ROUND(AVG(active_days), 2),
            ROUND(AVG(resources_used), 2),
            ROUND(AVG(assessment_submissions), 2),
            ROUND(AVG(average_score), 2)
        FROM analytics_student_engagement
        GROUP BY final_result
        """,
    ),
)


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


def scalar(engine: Engine, sql: str) -> int:
    with engine.connect() as connection:
        return int(connection.execute(text(sql)).scalar_one())


def check_clean_layer(engine: Engine) -> None:
    print("Checking cleaned-layer row counts ...")
    for table, expected in EXPECTED_CLEAN_COUNTS.items():
        actual = scalar(engine, f"SELECT COUNT(*) FROM `{table}`")
        print(f"  {table}: {actual:,}")
        if actual != expected:
            raise RuntimeError(
                f"{table} has {actual:,} rows; expected {expected:,}. "
                "Run task6_transform_clean.py first."
            )


def recreate_analytics_layer(engine: Engine) -> None:
    drop_order = (
        "analytics_engagement_by_result",
        "analytics_assessment_performance",
        "analytics_completion_by_presentation",
        "analytics_student_engagement",
    )
    with engine.begin() as connection:
        for table in drop_order:
            connection.execute(text(f"DROP TABLE IF EXISTS `{table}`"))
        for statement in ANALYTICS_DDL:
            connection.execute(text(statement))


def write_log(
    engine: Engine,
    table: str,
    row_count: int,
    duration: float,
) -> None:
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                INSERT INTO etl_run_log (
                    pipeline_stage,
                    target_table,
                    row_count,
                    duration_seconds,
                    status,
                    message
                ) VALUES (
                    'analytics_build',
                    :target_table,
                    :row_count,
                    :duration_seconds,
                    'SUCCESS',
                    'Analytics table created and validated.'
                )
                """
            ),
            {
                "target_table": table,
                "row_count": row_count,
                "duration_seconds": round(duration, 2),
            },
        )


def build_analytics(engine: Engine) -> None:
    for position, build in enumerate(ANALYTICS_BUILDS, start=1):
        print(
            f"[{position}/4] Building {build.table} ...",
            flush=True,
        )
        if position == 1:
            print(
                "      Aggregating 8.46 million interaction rows; "
                "this may take several minutes.",
                flush=True,
            )
        started = time.perf_counter()
        with engine.begin() as connection:
            connection.execute(text(build.sql))
        actual = scalar(engine, f"SELECT COUNT(*) FROM `{build.table}`")
        duration = time.perf_counter() - started
        if actual != build.expected_rows:
            raise RuntimeError(
                f"{build.table} has {actual:,} rows; "
                f"expected {build.expected_rows:,}."
            )
        write_log(engine, build.table, actual, duration)
        print(f"      {actual:,} rows in {duration:,.2f} seconds", flush=True)


def validate_analytics(engine: Engine) -> None:
    print("Running analytics-layer validation ...", flush=True)
    checks = {
        "student_analytics_rows": (
            "SELECT COUNT(*) FROM analytics_student_engagement",
            32_593,
        ),
        "completion_registrations": (
            """
            SELECT SUM(registered_students)
            FROM analytics_completion_by_presentation
            """,
            32_593,
        ),
        "engagement_registrations": (
            "SELECT SUM(registrations) FROM analytics_engagement_by_result",
            32_593,
        ),
        "invalid_completion_rates": (
            """
            SELECT COUNT(*)
            FROM analytics_completion_by_presentation
            WHERE successful_completion_rate_pct NOT BETWEEN 0 AND 100
            """,
            0,
        ),
        "invalid_assessment_scores": (
            """
            SELECT COUNT(*)
            FROM analytics_assessment_performance
            WHERE average_score IS NOT NULL
              AND average_score NOT BETWEEN 0 AND 100
            """,
            0,
        ),
    }
    for name, (sql, expected) in checks.items():
        actual = scalar(engine, sql)
        print(f"  {name}: {actual:,}", flush=True)
        if actual != expected:
            raise RuntimeError(
                f"Analytics validation failed for {name}: "
                f"found {actual:,}, expected {expected:,}."
            )

    with engine.begin() as connection:
        for table in (
            "analytics_student_engagement",
            "analytics_completion_by_presentation",
            "analytics_assessment_performance",
            "analytics_engagement_by_result",
        ):
            connection.execute(text(f"ANALYZE TABLE `{table}`"))


def print_result_summary(engine: Engine) -> None:
    print("\nEngagement by final result:")
    with engine.connect() as connection:
        rows = connection.execute(
            text(
                """
                SELECT
                    final_result,
                    registrations,
                    average_total_clicks,
                    average_active_days,
                    average_resources_used
                FROM analytics_engagement_by_result
                ORDER BY average_total_clicks DESC
                """
            )
        ).mappings()
        for row in rows:
            print(
                f"  {row['final_result']}: {row['registrations']:,} registrations, "
                f"{row['average_total_clicks']} average clicks, "
                f"{row['average_active_days']} average active days, "
                f"{row['average_resources_used']} average resources"
            )


def main() -> int:
    try:
        engine = build_engine()
        check_clean_layer(engine)
        print("\nThe analytics_* tables in oulad_etl will be replaced.")
        confirmation = input("Type ANALYTICS to continue: ").strip()
        if confirmation != "ANALYTICS":
            print("Cancelled. The analytics layer was not changed.")
            return 0

        print("\nRecreating the analytics layer ...", flush=True)
        recreate_analytics_layer(engine)
        build_analytics(engine)
        validate_analytics(engine)
        print_result_summary(engine)
        print("\nAnalytics layer completed successfully.")
        return 0
    except Exception as error:
        print(f"\nANALYTICS BUILD FAILED: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
