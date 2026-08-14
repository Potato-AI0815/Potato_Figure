# Dependency Resolution Report

Date: 2026-08-10
Purpose: record real, callable skill IDs for the Potato Publication Figure
Workflow orchestrator (Task B) and Potato Figure Audit (Task A).

## Environment scan method

Scanned `~/.config/opencode/skills/` (64 skills) for skill directories with
SKILL.md; read `name` / `description` / `version` from frontmatter. No
assumptions made from names alone.

## Installation actions taken

| Action | Result |
|---|---|
| Install `potato-figure-audit` (v0.3.0-alpha) into `~/.config/opencode/skills/potato-figure-audit` | ✅ done — now a callable skill |
| Install `nature-statistics` | ⛔ **NOT installed** — no authentic third-party source exists on this machine and GitHub search returned nothing. Installing a fabricated/unknown package would violate the "no copying third-party skill source" rule. The orchestrator degrades gracefully instead (see Notes). |

## Resolved dependencies

| Role | Detected skill id | Version | License | Path | Status |
|---|---|---|---|---|---|
| STATISTICS_PROVIDER | **NOT FOUND** | — | — | — | **missing** — graceful degradation: `USER_PROVIDED_STATISTICS` / `STATISTICAL_REVIEW_REQUIRED` |
| FIGURE_GENERATOR | `nature-figure` | 2.0.0 | third-party | `~/.config/opencode/skills/nature-figure` | available (preferred external provider) |
| FIGURE_AUDITOR | `potato-figure-audit` | historical 0.3.0-alpha installed; 0.4.0-alpha development line | MIT | `~/.config/opencode/skills/potato-figure-audit` + `<workspace>/Potato_Figure_Audit_v0.4.0-alpha` | available (core / preferred) |
| PAPER_SPINE_PROVIDER | `paper-spine` | not stated | third-party | `~/.config/opencode/skills/paper-spine` | available (preferred external provider) |
| MANUSCRIPT_WRITING (adjacent) | `nature-writing` | 1.0.0 | third-party | `~/.config/opencode/skills/nature-writing` | available (not required by workflow) |

## Notes

- `nature-statistics` does **not** exist on this machine (64 skills scanned;
  none provides a statistical-review capability). The orchestrator must not
  fabricate a statistics provider. Fallbacks:
  - `USER_PROVIDED_STATISTICS` (user supplies statistics_contract.yaml), or
  - `STATISTICAL_REVIEW_REQUIRED` (mark stage UNAVAILABLE, never fake PASS).
- `potato-figure-audit` is installed as a skill and is the orchestrator's
  **core / preferred** FIGURE_AUDITOR, version-bumped to v0.4.0 in Task A.
  It remains generator-agnostic and Nature-independent.
- `nature-figure` / `paper-spine` are **preferred external providers**:
  never bundled, never redistributed, never modified; users install them
  under their own licenses.

## License boundary

Third-party skills are not bundled or redistributed. Users must install them
independently under their respective licenses.

| dependency | role | detected_skill_id | version | license | required/preferred/optional | fallback |
|---|---|---|---|---|---|---|
| potato-figure-audit | FIGURE_AUDITOR | potato-figure-audit | 0.4.0-alpha (after Task A) | MIT | preferred/core | USER_PROVIDED_REVIEW or MANUAL |
| nature-figure | FIGURE_GENERATOR | nature-figure | 2.0.0 | third-party | preferred external | USER_PROVIDED_FIGURE |
| nature-statistics | STATISTICS_PROVIDER | — | — | — | preferred external | USER_PROVIDED_STATISTICS / STATISTICAL_REVIEW_REQUIRED |
| paper-spine | PAPER_SPINE_PROVIDER | paper-spine | unknown | third-party | preferred external | USER_PROVIDED_MISSION / NOT_EVALUABLE |
