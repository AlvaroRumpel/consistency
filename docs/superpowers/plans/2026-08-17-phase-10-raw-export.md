# Phase 10 — Raw File Export on the Error Screen

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the last open item of the v2 spec: when the data file can't be read, the error screen offers "Export raw file" so the user can rescue the bytes before anything overwrites them.

**Architecture:** `GoalsRepository` gains `Future<String?> readRaw()` — the raw text of the main file, or of `.bak`, or null. `ErrorView` gains an optional `onExportRaw` callback; the three call sites pass one that reads the raw bytes and hands them to the existing `BackupService.exportBackup`. No new packages, no new state.

**Spec:** `docs/superpowers/specs/2026-08-15-consistency-v2-design.md` — Seção 4: *"Load falha (arquivo e `.bak`) → tela erro com 'tentar de novo' e 'exportar arquivo bruto'"*.

## Global Constraints

- `readRaw()` must never throw: unreadable/missing → `null`. It returns the main file's text when present, else `.bak`'s, else `null` (a corrupt main file is exactly what the user wants to rescue, so **do not** validate it).
- The export file name is `consistency-raw-YYYY-MM-DD.json` (distinct from a normal backup, which is valid JSON by construction).
- The button only shows when `onExportRaw != null`; the existing `ErrorView` uses (settings, calendar, day editor) all pass it. `ErrorView` stays dumb — no repository/plugin imports.
- Strings from ARB in both languages (`exportRawFile`, `rawExportEmpty`, `rawExportReady`, `couldNotExportRaw`), template descriptions only in EN (`test/arb_parity_test.dart` enforces it); the raw-string guard must stay green.
- Lints; `flutter analyze` clean; `flutter test --concurrency=1 --reporter expanded` green (182 baseline); `dart format lib test`; Conventional Commits.

---

### Task 1: `readRaw()` on the repository

**Files:**
- Modify: `lib/data/goals_repository.dart`, `lib/data/file_goals_repository.dart`, `lib/data/in_memory_goals_repository.dart`
- Test: `test/file_goals_repository_test.dart` (extend)

**Interface (produced):** `Future<String?> readRaw();` on `GoalsRepository`.
- `FileGoalsRepository.readRaw()`: `_main` text if it exists, else `_bak` text if it exists, else `null`; any `FileSystemException` → `null`. Route it through the existing `_enqueue` chain so it can't interleave with a write.
- `InMemoryGoalsRepository.readRaw()`: `stored == null ? null : jsonEncode(stored!.toJson())`, plus a settable `String? rawOverride` so a test can simulate corrupt bytes.

- [ ] **Step 1: failing tests** — (a) empty dir → null; (b) after a save → the text decodes to the saved data; (c) corrupt main + valid `.bak` → returns the **corrupt main** text (that's the point: rescue what's there, unaltered); (d) main deleted, `.bak` present → returns `.bak`'s text; (e) `moveToUndo()` then `readRaw()` → null.
- [ ] **Steps 2–5:** run → fail, implement, green, commit `feat: repository can read the raw data file`.

---

### Task 2: the button, wired

**Files:**
- Modify: `lib/widgets/error_view.dart` (optional `VoidCallback? onExportRaw` + outlined button), `lib/pages/settings_page.dart`, `lib/pages/calendar_page.dart`, `lib/widgets/day_editor.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_pt.arb`, `lib/main.dart` + `test/helpers.dart` if the repository isn't reachable from the widget tree (see below)
- Test: `test/raw_export_test.dart` (new)

Wiring: `AppStore` currently owns the repository privately. Add `Future<String?> readRaw() => _repo.readRaw();` to `AppStore` (one line, keeps the repo private) so the pages can call `context.read<AppStore>().readRaw()` and pass the text to `context.read<BackupService>().exportBackup(...)`. Put the shared handler in one place — a small `Future<void> exportRawFile(BuildContext context)` helper in `lib/widgets/error_view.dart`'s file or a new `lib/widgets/raw_export.dart` — so the three call sites are one line each.
Behaviour: null/empty raw → snackbar `rawExportEmpty` (`There's nothing to export.` / `Não há nada para exportar.`); success → `rawExportReady` (`Raw file ready to share.` / `Arquivo bruto pronto para compartilhar.`); throw → `couldNotExportRaw` (`Couldn't export the raw file.` / `Não foi possível exportar o arquivo bruto.`). Button label `exportRawFile` (`Export raw file` / `Exportar arquivo bruto`), outlined, icon `Icons.download_outlined`, below "Try again".

- [ ] **Step 1: failing widget test** — boot the app over a repository whose `load()` throws but whose `readRaw()` returns `'{corrupt'`; the error screen shows both buttons; tapping the raw export calls the fake `BackupService` with a name matching `consistency-raw-*.json` and the exact corrupt contents; with `readRaw()` returning null the snackbar says nothing to export.
- [ ] **Steps 2–5:** run → fail, implement, green, commit `feat: export the raw data file from the error screen`.

---

### Task 3: Smoke + tag

- [ ] On a device: corrupt `consistency.json` (e.g. `adb shell run-as com.acr.consistency` + truncate the file), open the app → error screen with both buttons; export → share sheet with `consistency-raw-<date>.json`; the shared file contains the corrupt bytes; "Try again" still retries. `git tag phase-10-done` and, if you want a release marker, `git tag v0.2.0`.

## Self-review

- Spec Seção 4's error-screen bullet is fully covered (retry + raw export); nothing else in the spec remains open.
- Names: `GoalsRepository.readRaw()`, `AppStore.readRaw()`, `ErrorView(onExportRaw:)`, `exportRawFile(context)`, ARB keys `exportRawFile/rawExportEmpty/rawExportReady/couldNotExportRaw`.
- No new packages; the existing `BackupService` does the sharing.
