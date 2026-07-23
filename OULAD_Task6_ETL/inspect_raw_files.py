import csv
from pathlib import Path

DATA_DIR = Path("data")

EXPECTED_FILES = {
    "courses.csv": [
        "code_module",
        "code_presentation",
        "module_presentation_length",
    ],
    "assessments.csv": [
        "code_module",
        "code_presentation",
        "id_assessment",
        "assessment_type",
        "date",
        "weight",
    ],
    "vle.csv": [
        "id_site",
        "code_module",
        "code_presentation",
        "activity_type",
        "week_from",
        "week_to",
    ],
    "studentInfo.csv": [
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
    ],
    "studentRegistration.csv": [
        "code_module",
        "code_presentation",
        "id_student",
        "date_registration",
        "date_unregistration",
    ],
    "studentAssessment.csv": [
        "id_assessment",
        "id_student",
        "date_submitted",
        "is_banked",
        "score",
    ],
    "studentVle.csv": [
        "code_module",
        "code_presentation",
        "id_student",
        "id_site",
        "date",
        "sum_click",
    ],
}

all_valid = True

for filename, expected_columns in EXPECTED_FILES.items():
    file_path = DATA_DIR / filename

    if not file_path.exists():
        print(f"[MISSING] {filename}")
        all_valid = False
        continue

    with file_path.open("r", encoding="utf-8-sig", newline="") as csv_file:
        reader = csv.reader(csv_file)
        found_columns = next(reader)

    size_mb = file_path.stat().st_size / (1024 * 1024)

    if found_columns == expected_columns:
        print(f"[OK] {filename}: {size_mb:,.2f} MB")
    else:
        print(f"[INVALID COLUMNS] {filename}")
        print(f"  Expected: {expected_columns}")
        print(f"  Found:    {found_columns}")
        all_valid = False

if all_valid:
    print("\nPreflight check passed: all seven raw files are ready.")
else:
    print("\nPreflight check failed: correct the issues shown above.")