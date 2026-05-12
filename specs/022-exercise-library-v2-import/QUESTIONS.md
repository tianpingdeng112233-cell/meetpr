## Q1: xlsx row count conflicts with SPEC acceptance count

**问题**: `SPEC.md` says the source xlsx contains 436 catalog rows (`#` seq 1-436), the generated JSON must contain 436 `Exercise` values, and `previewCatalog()` must total 439 rows. The actual source workbook at `~/Brain/wiki/projects/MeetPR/domain/exercise-library-v2.xlsx` has 436 rows including the header on the `动作库` sheet, data seq only 1-435, and `_meta!B4` says `总条数 = 435`.

**我倾向的选项**: A. Treat the source workbook as the source of truth and adjust the implementation/spec expectations to 435 imported rows + 3 synthetic competition lifts = 438 total. This follows the "不改 xlsx" constraint and avoids inventing a missing catalog entry.

**但不确定**: The spec repeatedly names 436 imported rows and 439 total rows, so there may be an intended row missing from the xlsx or a newer workbook not present locally. Please confirm whether to update the xlsx/source, or to change spec 022 expectations to 435/438 before implementation continues.
