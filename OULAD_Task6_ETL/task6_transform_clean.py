"""Transform OULAD raw staging tables into a constrained cleaned layer.

This is the Transform portion of the Task 6 ELT pipeline.  It operates only in
the oulad_etl schema, converts raw text to appropriate SQL types, standardises
known missing/inconsistent values, consolidates repeated student-VLE daily
records, and applies relational integrity constraints.
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
class TableLoad:
    table: str
    expected_rows: int
    sql: str


EXPECTED_STAGING_COUNTS = {
    "stg_courses": 22,
    "stg_assessments": 206,
    "stg_vle": 6_364,
    "stg_student_info": 32_593,
    "stg_student_registration": 32_593,
    "stg_student_assessment": 173_912,
    "stg_student_vle": 10_655_280,
}


CLEAN_DDL = (
    """
    CREATE TABLE clean_module_presentation (
        code_module VARCHAR(5) NOT NULL,
        code_presentation VARCHAR(5) NOT NULL,
        module_presentation_length INT NOT NULL,
        CONSTRAINT pk_clean_module_presentation
            PRIMARY KEY (code_module, code_presentation),
        CONSTRAINT chk_clean_module_length
            CHECK (module_presentation_length > 0)
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE clean_student (
        id_student INT NOT NULL,
        gender CHAR(1) NOT NULL,
        region VARCHAR(50) NOT NULL,
        highest_education VARCHAR(40) NOT NULL,
        imd_band VARCHAR(10),
        disability CHAR(1) NOT NULL,
        CONSTRAINT pk_clean_student PRIMARY KEY (id_student),
        CONSTRAINT chk_clean_student_gender CHECK (gender IN ('M', 'F')),
        CONSTRAINT chk_clean_student_disability CHECK (disability IN ('Y', 'N')),
        CONSTRAINT chk_clean_student_imd CHECK (
            imd_band IS NULL OR imd_band IN (
                '0-10%', '10-20%', '20-30%', '30-40%', '40-50%',
                '50-60%', '60-70%', '70-80%', '80-90%', '90-100%'
            )
        )
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE clean_registration (
        id_student INT NOT NULL,
        code_module VARCHAR(5) NOT NULL,
        code_presentation VARCHAR(5) NOT NULL,
        age_band VARCHAR(10) NOT NULL,
        date_registration INT,
        date_unregistration INT,
        num_of_prev_attempts INT NOT NULL DEFAULT 0,
        studied_credits INT NOT NULL,
        final_result VARCHAR(20) NOT NULL,
        CONSTRAINT pk_clean_registration
            PRIMARY KEY (id_student, code_module, code_presentation),
        CONSTRAINT fk_clean_registration_student
            FOREIGN KEY (id_student)
            REFERENCES clean_student (id_student),
        CONSTRAINT fk_clean_registration_presentation
            FOREIGN KEY (code_module, code_presentation)
            REFERENCES clean_module_presentation (code_module, code_presentation),
        CONSTRAINT chk_clean_registration_age
            CHECK (age_band IN ('0-35', '35-55', '55<=')),
        CONSTRAINT chk_clean_registration_attempts
            CHECK (num_of_prev_attempts >= 0),
        CONSTRAINT chk_clean_registration_credits
            CHECK (studied_credits > 0),
        CONSTRAINT chk_clean_registration_result
            CHECK (final_result IN ('Distinction', 'Pass', 'Fail', 'Withdrawn')),
        CONSTRAINT chk_clean_registration_dates CHECK (
            date_registration IS NULL
            OR date_unregistration IS NULL
            OR date_unregistration >= date_registration
        )
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE clean_assessment (
        id_assessment INT NOT NULL,
        code_module VARCHAR(5) NOT NULL,
        code_presentation VARCHAR(5) NOT NULL,
        assessment_type VARCHAR(10) NOT NULL,
        assessment_date INT,
        weight DECIMAL(5,2) NOT NULL,
        CONSTRAINT pk_clean_assessment PRIMARY KEY (id_assessment),
        CONSTRAINT uq_clean_assessment_context
            UNIQUE (id_assessment, code_module, code_presentation),
        CONSTRAINT fk_clean_assessment_presentation
            FOREIGN KEY (code_module, code_presentation)
            REFERENCES clean_module_presentation (code_module, code_presentation),
        CONSTRAINT chk_clean_assessment_type
            CHECK (assessment_type IN ('TMA', 'CMA', 'Exam')),
        CONSTRAINT chk_clean_assessment_weight
            CHECK (weight BETWEEN 0 AND 100)
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE clean_vle_resource (
        id_site INT NOT NULL,
        code_module VARCHAR(5) NOT NULL,
        code_presentation VARCHAR(5) NOT NULL,
        activity_type VARCHAR(50) NOT NULL,
        week_from INT,
        week_to INT,
        CONSTRAINT pk_clean_vle_resource PRIMARY KEY (id_site),
        CONSTRAINT uq_clean_vle_resource_context
            UNIQUE (id_site, code_module, code_presentation),
        CONSTRAINT fk_clean_vle_presentation
            FOREIGN KEY (code_module, code_presentation)
            REFERENCES clean_module_presentation (code_module, code_presentation),
        CONSTRAINT chk_clean_vle_weeks CHECK (
            (week_from IS NULL AND week_to IS NULL)
            OR (
                week_from IS NOT NULL
                AND week_to IS NOT NULL
                AND week_from >= 0
                AND week_to >= week_from
            )
        )
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE clean_student_assessment (
        id_assessment INT NOT NULL,
        id_student INT NOT NULL,
        code_module VARCHAR(5) NOT NULL,
        code_presentation VARCHAR(5) NOT NULL,
        date_submitted INT NOT NULL,
        is_banked TINYINT NOT NULL DEFAULT 0,
        score INT,
        CONSTRAINT pk_clean_student_assessment
            PRIMARY KEY (id_assessment, id_student),
        CONSTRAINT fk_clean_student_assessment_assessment
            FOREIGN KEY (id_assessment, code_module, code_presentation)
            REFERENCES clean_assessment (
                id_assessment, code_module, code_presentation
            ),
        CONSTRAINT fk_clean_student_assessment_registration
            FOREIGN KEY (id_student, code_module, code_presentation)
            REFERENCES clean_registration (
                id_student, code_module, code_presentation
            ),
        CONSTRAINT chk_clean_student_assessment_banked
            CHECK (is_banked IN (0, 1)),
        CONSTRAINT chk_clean_student_assessment_score
            CHECK (score IS NULL OR score BETWEEN 0 AND 100),
        INDEX idx_clean_student_assessment_student
            (id_student, code_module, code_presentation)
    ) ENGINE=InnoDB
    """,
    # The large table is indexed after its set-based load for better performance.
    """
    CREATE TABLE clean_student_vle_interaction (
        code_module VARCHAR(5) NOT NULL,
        code_presentation VARCHAR(5) NOT NULL,
        id_student INT NOT NULL,
        id_site INT NOT NULL,
        interaction_date INT NOT NULL,
        sum_click INT NOT NULL
    ) ENGINE=InnoDB
    """,
)


SMALL_TABLE_LOADS = (
    TableLoad(
        "clean_module_presentation",
        22,
        """
        INSERT INTO clean_module_presentation
            (code_module, code_presentation, module_presentation_length)
        SELECT
            TRIM(code_module),
            TRIM(code_presentation),
            CAST(TRIM(module_presentation_length) AS UNSIGNED)
        FROM stg_courses
        """,
    ),
    TableLoad(
        "clean_student",
        28_785,
        """
        INSERT INTO clean_student
            (id_student, gender, region, highest_education, imd_band, disability)
        SELECT
            CAST(TRIM(id_student) AS UNSIGNED),
            MAX(TRIM(gender)),
            MAX(TRIM(region)),
            MAX(TRIM(highest_education)),
            MAX(
                CASE
                    WHEN TRIM(imd_band) IN ('', '?') THEN NULL
                    WHEN TRIM(imd_band) = '10-20' THEN '10-20%'
                    ELSE TRIM(imd_band)
                END
            ),
            MAX(TRIM(disability))
        FROM stg_student_info
        GROUP BY CAST(TRIM(id_student) AS UNSIGNED)
        """,
    ),
    TableLoad(
        "clean_registration",
        32_593,
        """
        INSERT INTO clean_registration (
            id_student,
            code_module,
            code_presentation,
            age_band,
            date_registration,
            date_unregistration,
            num_of_prev_attempts,
            studied_credits,
            final_result
        )
        SELECT
            CAST(TRIM(si.id_student) AS UNSIGNED),
            TRIM(si.code_module),
            TRIM(si.code_presentation),
            TRIM(si.age_band),
            CAST(NULLIF(NULLIF(TRIM(sr.date_registration), '?'), '') AS SIGNED),
            CAST(NULLIF(NULLIF(TRIM(sr.date_unregistration), '?'), '') AS SIGNED),
            CAST(TRIM(si.num_of_prev_attempts) AS UNSIGNED),
            CAST(TRIM(si.studied_credits) AS UNSIGNED),
            TRIM(si.final_result)
        FROM stg_student_info AS si
        JOIN stg_student_registration AS sr
          ON TRIM(sr.code_module) = TRIM(si.code_module)
         AND TRIM(sr.code_presentation) = TRIM(si.code_presentation)
         AND CAST(TRIM(sr.id_student) AS UNSIGNED)
             = CAST(TRIM(si.id_student) AS UNSIGNED)
        """,
    ),
    TableLoad(
        "clean_assessment",
        206,
        """
        INSERT INTO clean_assessment (
            id_assessment,
            code_module,
            code_presentation,
            assessment_type,
            assessment_date,
            weight
        )
        SELECT
            CAST(TRIM(id_assessment) AS UNSIGNED),
            TRIM(code_module),
            TRIM(code_presentation),
            TRIM(assessment_type),
            CAST(NULLIF(NULLIF(TRIM(`date`), '?'), '') AS SIGNED),
            CAST(TRIM(weight) AS DECIMAL(5,2))
        FROM stg_assessments
        """,
    ),
    TableLoad(
        "clean_vle_resource",
        6_364,
        """
        INSERT INTO clean_vle_resource (
            id_site,
            code_module,
            code_presentation,
            activity_type,
            week_from,
            week_to
        )
        SELECT
            CAST(TRIM(id_site) AS UNSIGNED),
            TRIM(code_module),
            TRIM(code_presentation),
            TRIM(activity_type),
            CAST(NULLIF(NULLIF(TRIM(week_from), '?'), '') AS SIGNED),
            CAST(NULLIF(NULLIF(TRIM(week_to), '?'), '') AS SIGNED)
        FROM stg_vle
        """,
    ),
    TableLoad(
        "clean_student_assessment",
        173_912,
        """
        INSERT INTO clean_student_assessment (
            id_assessment,
            id_student,
            code_module,
            code_presentation,
            date_submitted,
            is_banked,
            score
        )
        SELECT
            CAST(TRIM(sa.id_assessment) AS UNSIGNED),
            CAST(TRIM(sa.id_student) AS UNSIGNED),
            a.code_module,
            a.code_presentation,
            CAST(TRIM(sa.date_submitted) AS SIGNED),
            CAST(TRIM(sa.is_banked) AS UNSIGNED),
            CAST(NULLIF(NULLIF(TRIM(sa.score), '?'), '') AS SIGNED)
        FROM stg_student_assessment AS sa
        JOIN clean_assessment AS a
          ON a.id_assessment = CAST(TRIM(sa.id_assessment) AS UNSIGNED)
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

    connection_url = URL.create(
        drivername="mysql+pymysql",
        username=required_environment("MYSQL_USER"),
        password=os.getenv("MYSQL_PASSWORD", ""),
        host=os.getenv("MYSQL_HOST", "127.0.0.1"),
        port=int(os.getenv("MYSQL_PORT", "3306")),
        database=database,
    )
    return create_engine(
        connection_url,
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


def check_staging_counts(engine: Engine) -> None:
    print("Checking staging row counts ...")
    for table, expected in EXPECTED_STAGING_COUNTS.items():
        actual = scalar(engine, f"SELECT COUNT(*) FROM `{table}`")
        print(f"  {table}: {actual:,} rows")
        if actual != expected:
            raise RuntimeError(
                f"{table} has {actual:,} rows; expected {expected:,}. "
                "Run task6_load_staging.py before this transformation."
            )


def recreate_clean_layer(engine: Engine) -> None:
    drop_order = (
        "clean_student_vle_interaction",
        "clean_student_assessment",
        "clean_registration",
        "clean_vle_resource",
        "clean_assessment",
        "clean_student",
        "clean_module_presentation",
    )
    with engine.begin() as connection:
        connection.execute(text("SET FOREIGN_KEY_CHECKS = 0"))
        for table in drop_order:
            connection.execute(text(f"DROP TABLE IF EXISTS `{table}`"))
        connection.execute(text("SET FOREIGN_KEY_CHECKS = 1"))
        for statement in CLEAN_DDL:
            connection.execute(text(statement))


def write_log(
    engine: Engine,
    table: str,
    row_count: int,
    duration: float,
    message: str,
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
                    'clean_transform',
                    :target_table,
                    :row_count,
                    :duration_seconds,
                    'SUCCESS',
                    :message
                )
                """
            ),
            {
                "target_table": table,
                "row_count": row_count,
                "duration_seconds": round(duration, 2),
                "message": message,
            },
        )


def load_small_tables(engine: Engine) -> None:
    for position, load in enumerate(SMALL_TABLE_LOADS, start=1):
        print(f"[{position}/6] Transforming {load.table} ...", flush=True)
        started = time.perf_counter()
        with engine.begin() as connection:
            connection.execute(text(load.sql))
        actual = scalar(engine, f"SELECT COUNT(*) FROM `{load.table}`")
        duration = time.perf_counter() - started
        if actual != load.expected_rows:
            raise RuntimeError(
                f"{load.table} has {actual:,} rows; "
                f"expected {load.expected_rows:,}."
            )
        write_log(
            engine,
            load.table,
            actual,
            duration,
            "Typed transformation completed and expected row count matched.",
        )
        print(f"      {actual:,} rows in {duration:,.2f} seconds", flush=True)


def ensure_staging_vle_index(engine: Engine) -> None:
    with engine.connect() as connection:
        exists = int(
            connection.execute(
                text(
                    """
                    SELECT COUNT(*)
                    FROM information_schema.statistics
                    WHERE table_schema = 'oulad_etl'
                      AND table_name = 'stg_student_vle'
                      AND index_name = 'idx_stg_student_vle_grain'
                    """
                )
            ).scalar_one()
        )

    if exists:
        print("Large staging index already exists.", flush=True)
        return

    print(
        "Creating the large staging index. This may take several minutes ...",
        flush=True,
    )
    started = time.perf_counter()
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                ALTER TABLE stg_student_vle
                ADD INDEX idx_stg_student_vle_grain (
                    code_module,
                    code_presentation,
                    id_student,
                    id_site,
                    `date`
                )
                """
            )
        )
    print(
        f"Large staging index created in "
        f"{time.perf_counter() - started:,.2f} seconds.",
        flush=True,
    )


def load_large_interaction_table(engine: Engine) -> None:
    print(
        "[7/7] Consolidating student-VLE duplicates. "
        "This is the longest transformation ...",
        flush=True,
    )
    started = time.perf_counter()
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                INSERT INTO clean_student_vle_interaction (
                    code_module,
                    code_presentation,
                    id_student,
                    id_site,
                    interaction_date,
                    sum_click
                )
                SELECT
                    TRIM(code_module),
                    TRIM(code_presentation),
                    CAST(TRIM(id_student) AS UNSIGNED),
                    CAST(TRIM(id_site) AS UNSIGNED),
                    CAST(TRIM(`date`) AS SIGNED),
                    SUM(CAST(TRIM(sum_click) AS UNSIGNED))
                FROM stg_student_vle
                FORCE INDEX (idx_stg_student_vle_grain)
                GROUP BY
                    code_module,
                    code_presentation,
                    id_student,
                    id_site,
                    `date`
                """
            )
        )

    actual = scalar(engine, "SELECT COUNT(*) FROM clean_student_vle_interaction")
    duration = time.perf_counter() - started
    expected = 8_459_320
    if actual != expected:
        raise RuntimeError(
            f"clean_student_vle_interaction has {actual:,} rows; "
            f"expected {expected:,}."
        )
    write_log(
        engine,
        "clean_student_vle_interaction",
        actual,
        duration,
        "2,195,960 repeated raw daily-grain rows were consolidated.",
    )
    print(f"      {actual:,} cleaned rows in {duration:,.2f} seconds", flush=True)


def apply_large_table_constraints(engine: Engine) -> None:
    print(
        "Applying the large-table primary key and foreign keys. "
        "This may take several minutes ...",
        flush=True,
    )
    started = time.perf_counter()
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                ALTER TABLE clean_student_vle_interaction
                    ADD CONSTRAINT pk_clean_student_vle
                        PRIMARY KEY (
                            code_module,
                            code_presentation,
                            id_student,
                            id_site,
                            interaction_date
                        ),
                    ADD INDEX idx_clean_student_vle_registration
                        (id_student, code_module, code_presentation),
                    ADD INDEX idx_clean_student_vle_resource
                        (id_site, code_module, code_presentation),
                    ADD CONSTRAINT fk_clean_student_vle_registration
                        FOREIGN KEY (
                            id_student, code_module, code_presentation
                        ) REFERENCES clean_registration (
                            id_student, code_module, code_presentation
                        ),
                    ADD CONSTRAINT fk_clean_student_vle_resource
                        FOREIGN KEY (
                            id_site, code_module, code_presentation
                        ) REFERENCES clean_vle_resource (
                            id_site, code_module, code_presentation
                        )
                """
            )
        )
    print(
        f"Large-table constraints applied in "
        f"{time.perf_counter() - started:,.2f} seconds.",
        flush=True,
    )


def validate_clean_layer(engine: Engine) -> None:
    print("Running cleaned-layer data-quality checks ...", flush=True)
    checks = {
        "nonpositive_click_rows": """
            SELECT COUNT(*)
            FROM clean_student_vle_interaction
            WHERE sum_click <= 0
        """,
        "interaction_without_registration": """
            SELECT COUNT(*)
            FROM clean_student_vle_interaction AS i
            LEFT JOIN clean_registration AS r
              ON r.id_student = i.id_student
             AND r.code_module = i.code_module
             AND r.code_presentation = i.code_presentation
            WHERE r.id_student IS NULL
        """,
        "interaction_without_resource": """
            SELECT COUNT(*)
            FROM clean_student_vle_interaction AS i
            LEFT JOIN clean_vle_resource AS v
              ON v.id_site = i.id_site
             AND v.code_module = i.code_module
             AND v.code_presentation = i.code_presentation
            WHERE v.id_site IS NULL
        """,
    }
    for name, sql in checks.items():
        result = scalar(engine, sql)
        print(f"  {name}: {result:,}", flush=True)
        if result != 0:
            raise RuntimeError(f"Cleaned-layer quality check failed: {name}")

    with engine.begin() as connection:
        for table in (
            "clean_module_presentation",
            "clean_student",
            "clean_registration",
            "clean_assessment",
            "clean_vle_resource",
            "clean_student_assessment",
            "clean_student_vle_interaction",
        ):
            connection.execute(text(f"ANALYZE TABLE `{table}`"))


def print_summary(engine: Engine) -> None:
    tables = (
        "clean_module_presentation",
        "clean_student",
        "clean_registration",
        "clean_assessment",
        "clean_vle_resource",
        "clean_student_assessment",
        "clean_student_vle_interaction",
    )
    print("\nCleaned-layer row counts:")
    for table in tables:
        print(f"  {table}: {scalar(engine, f'SELECT COUNT(*) FROM `{table}`'):,}")
    print("  duplicate student-VLE rows consolidated: 2,195,960")


def main() -> int:
    try:
        engine = build_engine()
        check_staging_counts(engine)

        print("\nThe existing clean_* tables in oulad_etl will be replaced.")
        confirmation = input("Type CLEAN to continue: ").strip()
        if confirmation != "CLEAN":
            print("Cancelled. The cleaned layer was not changed.")
            return 0

        print("\nRecreating the cleaned layer ...", flush=True)
        recreate_clean_layer(engine)
        load_small_tables(engine)
        ensure_staging_vle_index(engine)
        load_large_interaction_table(engine)
        apply_large_table_constraints(engine)
        validate_clean_layer(engine)
        print_summary(engine)
        print("\nCleaned-layer transformation completed successfully.")
        return 0
    except Exception as error:
        print(f"\nCLEAN TRANSFORMATION FAILED: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
