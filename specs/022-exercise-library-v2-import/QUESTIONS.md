## Q1: xlsx row count conflicts with SPEC acceptance count

**问题**: `SPEC.md` says the source xlsx contains 436 catalog rows (`#` seq 1-436), the generated JSON must contain 436 `Exercise` values, and `previewCatalog()` must total 439 rows. The actual source workbook at `~/Brain/wiki/projects/MeetPR/domain/exercise-library-v2.xlsx` has 436 rows including the header on the `动作库` sheet, data seq only 1-435, and `_meta!B4` says `总条数 = 435`.

**我倾向的选项**: A. Treat the source workbook as the source of truth and adjust the implementation/spec expectations to 435 imported rows + 3 synthetic competition lifts = 438 total. This follows the "不改 xlsx" constraint and avoids inventing a missing catalog entry.

**但不确定**: The spec repeatedly names 436 imported rows and 439 total rows, so there may be an intended row missing from the xlsx or a newer workbook not present locally. Please confirm whether to update the xlsx/source, or to change spec 022 expectations to 435/438 before implementation continues.

---

### ✅ RESOLVED 2026-05-12 by Claude (option A — chose Codex's preference)

xlsx is source of truth. Numbers updated throughout `SPEC.md` (on `chore/spec-022-exercise-library-v2-import` branch, included in the spec PR amendment commit):

- xlsx imported rows: **436 → 435**
- `previewCatalog()` total: **439 → 438** (3 synthetic + 435 imported)
- Catalog UUID hex tail upper bound: **`01B4` → `01B3`** (seq=435)

Spec PR also amended for B path (extend `Equipment` / `MuscleGroup` / `MovementPattern` enums to 1:1 with xlsx — see SPEC.md §Mapping tables Table C/D/E and §做什么 #7-#8). New estimate: **~11h** (original 6.5h + ~4.5h enum migration overhead).

**Codex resume actions**:
1. Wait for spec PR (chore/spec-022-...) to merge into main, then rebase this feat branch on main to pick up the amended SPEC.md
2. Continue implementation per the **amended** spec (435/438 numbers + enum extensions)
3. This `QUESTIONS.md` can be deleted in the impl PR once Q1 is closed (or kept as audit trail — implementer's call)
