"""Load the seven raw OULAD CSV files into MySQL staging tables.

This is the Extract/Load portion of the Task 6 ELT pipeline.  It reads the
connection settings from .env, creates raw staging tables in oulad_etl, and
uses MySQL LOAD DATA LOCAL INFILE for fast bulk loading.  It never touches the
completed oulad_db schema.
"""

from __future__ import annotations

import os
import sys
import time
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL, Engine


@dataclass(frozen=True)
class SourceFile:
    filename: str
    table: str
    columns: tuple[str, ...]
    expected_rows: int


SOURCES = (
    SourceFile(
        "courses.csv",
        "stg_courses",
        ("code_module", "code_presentation", "module_presentation_length"),
        22,
    ),
    SourceFile(
        "assessments.csv",
        "stg_assessments",
        (
            "code_module",
            "code_presentation",
            "id_assessment",
            "assessment_type",
            "date",
            "weight",
        ),
        206,
    ),
    SourceFile(
        "vle.csv",
        "stg_vle",
        (
            "id_site",
            "code_module",
            "code_presentation",
            "activity_type",
            "week_from",
            "week_to",
        ),
        6_364,
    ),
    SourceFile(
        "studentInfo.csv",
        "stg_student_info",
        (
            "code_module",
            "code_presentation",
            "id_student",
            "gender",
            "region",
            "highest_education",
            "imd_band",
            "age_band",
            "num_of_prev_attempts",
            "studied_credits",
            "disability",
            "final_result",
        ),
        32_593,
    ),
    SourceFile(
        "studentRegistration.csv",
        "stg_student_registration",
        (
            "code_module",
            "code_presentation",
            "id_student",
            "date_registration",
            "date_unregistration",
        ),
        32_593,
    ),
    SourceFile(
        "studentAssessment.csv",
        "stg_student_assessment",
        (
            "id_assessment",
            "id_student",
            "date_submitted",
            "is_banked",
            "score",
        ),
        173_912,
    ),
    SourceFile(
        "studentVle.csv",
        "stg_student_vle",
        (
            "code_module",
            "code_presentation",
            "id_student",
            "id_site",
            "date",
            "sum_click",
        ),
        10_655_280,
    ),
)


STAGING_DDL = (
    """
    CREATE TABLE IF NOT EXISTS stg_courses (
        code_module VARCHAR(20),
        code_presentation VARCHAR(20),
        module_presentation_length VARCHAR(20)
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS stg_assessments (
        code_module VARCHAR(20),
        code_presentation VARCHAR(20),
        id_assessment VARCHAR(20),
        assessment_type VARCHAR(20),
        `date` VARCHAR(20),
        weight VARCHAR(20)
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS stg_vle (
        id_site VARCHAR(20),
        code_module VARCHAR(20),
        code_presentation VARCHAR(20),
        activity_type VARCHAR(50),
        week_from VARCHAR(20),
        week_to VARCHAR(20)
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS stg_student_info (
        code_module VARCHAR(20),
        code_presentation VARCHAR(20),
        id_student VARCHAR(20),
        gender VARCHAR(10),
        region VARCHAR(100),
        highest_education VARCHAR(100),
        imd_band VARCHAR(20),
        age_band VARCHAR(20),
        num_of_prev_attempts VARCHAR(20),
        studied_credits VARCHAR(20),
        disability VARCHAR(10),
        final_result VARCHAR(30)
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS stg_student_registration (
        code_module VARCHAR(20),
        code_presentation VARCHAR(20),
        id_student VARCHAR(20),
        date_registration VARCHAR(20),
        date_unregistration VARCHAR(20)
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS stg_student_assessment (
        id_assessment VARCHAR(20),
        id_student VARCHAR(20),
        date_submitted VARCHAR(20),
        is_banked VARCHAR(10),
        score VARCHAR(20)
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS stg_student_vle (
        code_module VARCHAR(20),
        code_presentation VARCHAR(20),
        id_student VARCHAR(20),
        id_site VARCHAR(20),
        `date` VARCHAR(20),
        sum_click VARCHAR(20)
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS etl_run_log (
        log_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        pipeline_stage VARCHAR(40) NOT NULL,
        source_file VARCHAR(255),
        target_table VARCHAR(64),
        row_count BIGINT,
        duration_seconds DECIMAL(12,2),
        status VARCHAR(20) NOT NULL,
        message VARCHAR(500),
        logged_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (log_id)
    ) ENGINE=InnoDB
    """,
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
            "Safety stop: MYSQL_DATABASE must be oulad_etl for this Task 6 loader."
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
            "local_infile": True,
            "connect_timeout": 30,
            "read_timeout": 7200,
            "write_timeout": 7200,
        },
    )


def create_staging_tables(engine: Engine) -> None:
    with engine.begin() as connection:
        for statement in STAGING_DDL:
            connection.execute(text(statement))


def detect_line_terminator(file_path: Path) -> str:
    with file_path.open("rb") as source_file:
        sample = source_file.read(16_384)
    return "\\r\\n" if b"\r\n" in sample else "\\n"


def log_result(
    engine: Engine,
    source: SourceFile,
    row_count: int | None,
    duration: float,
    status: str,
    message: str,
) -> None:
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                INSERT INTO etl_run_log (
                    pipeline_stage,
                    source_file,
                    target_table,
                    row_count,
                    duration_seconds,
                    status,
                    message
                ) VALUES (
                    'staging_load',
                    :source_file,
                    :target_table,
                    :row_count,
                    :duration_seconds,
                    :status,
                    :message
                )
                """
            ),
            {
                "source_file": source.filename,
                "target_table": source.table,
                "row_count": row_count,
                "duration_seconds": round(duration, 2),
                "status": status,
                "message": message[:500],
            },
        )


def load_source(engine: Engine, source: SourceFile, data_dir: Path) -> int:
    file_path = (data_dir / source.filename).resolve()
    if not file_path.exists():
        raise FileNotFoundError(f"Raw file not found: {file_path}")

    # Path and identifiers come only from the fixed SOURCES configuration above.
    mysql_path = file_path.as_posix().replace("'", "''")
    columns = ", ".join(f"`{column}`" for column in source.columns)
    line_terminator = detect_line_terminator(file_path)

    load_sql = f"""
        LOAD DATA LOCAL INFILE '{mysql_path}'
        INTO TABLE `{source.table}`
        CHARACTER SET utf8mb4
        FIELDS TERMINATED BY ','
        OPTIONALLY ENCLOSED BY '"'
        LINES TERMINATED BY '{line_terminator}'
        IGNORE 1 LINES
        ({columns})
    """

    with engine.begin() as connection:
        connection.execute(text(f"TRUNCATE TABLE `{source.table}`"))
        connection.exec_driver_sql(load_sql)
        row_count = int(
            connection.execute(
                text(f"SELECT COUNT(*) FROM `{source.table}`")
            ).scalar_one()
        )

    if row_count != source.expected_rows:
        raise RuntimeError(
            f"{source.table} loaded {row_count:,} rows; "
            f"expected {source.expected_rows:,}."
        )

    return row_count


def check_local_infile(engine: Engine) -> None:
    with engine.connect() as connection:
        value = connection.execute(
            text("SELECT @@GLOBAL.local_infile")
        ).scalar_one()
    if int(value) != 1:
        raise RuntimeError(
            "MySQL local_infile is OFF. In Workbench, run "
            "SET GLOBAL local_infile = ON; and then run this loader again."
        )


def main() -> int:
    try:
        load_dotenv()
        data_dir = Path(os.getenv("DATA_DIR", "data"))
        engine = build_engine()
        check_local_infile(engine)
        create_staging_tables(engine)

        print("Target schema: oulad_etl")
        print("Seven staging tables will be truncated and reloaded.")
        confirmation = input("Type LOAD to continue: ").strip()
        if confirmation != "LOAD":
            print("Cancelled. No staging data was changed.")
            return 0

        total_rows = 0
        for position, source in enumerate(SOURCES, start=1):
            print(f"\n[{position}/7] Loading {source.filename} -> {source.table} ...")
            started = time.perf_counter()
            try:
                row_count = load_source(engine, source, data_dir)
                duration = time.perf_counter() - started
                total_rows += row_count
                message = "Row count matched the expected source count."
                log_result(
                    engine, source, row_count, duration, "SUCCESS", message
                )
                print(f"      {row_count:,} rows loaded in {duration:,.2f} seconds")
            except Exception as error:
                duration = time.perf_counter() - started
                try:
                    log_result(
                        engine, source, None, duration, "FAILED", str(error)
                    )
                except Exception:
                    pass
                raise

        print("\nStaging load completed successfully.")
        print(f"Total raw rows loaded: {total_rows:,}")
        print("Expected total raw rows: 10,900,970")
        return 0
    except Exception as error:
        print(f"\nSTAGING LOAD FAILED: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
