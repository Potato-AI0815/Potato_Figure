# R0 Legacy Residue Audit

## Gate result

```text
status: PASS
legacy_residue_before: 14
legacy_residue_after_unresolved: 0
core_architecture_changed: no
scientific_logic_changed: no
visual_profile_changed: no
execution_behavior_changed: no
```

## Files scanned

The full operational v0.2 directory was scanned before and after the cleanup:

1. `SKILL.md`
2. `profiles/a4-working.yaml`
3. `profiles/high-impact-omics.yaml`
4. `profiles/journal-final.yaml`
5. `references/a4-layout-and-export.md`
6. `references/color-system.md`
7. `references/scientific-integrity.md`
8. `references/three-source-synthesis.md`
9. `references/user-approved-benchmark-01.md`
10. `references/visual-art-direction.md`
11. `references/visual-qa.md`
12. `themes/potato_theme_v02.R`

The generated R0 audit files were also included in the final scan as audit records, not as operational rules.

## Residues found and resolved

### 1. Frontmatter

Before, the description presented an A4 authoring canvas and a fixed accessible palette as defining features of the whole Skill.

After, it defines Potato Figure through evidence-led hierarchy, profile-driven art direction, panel-level provenance/Source Data, and independent scientific, delivery, and visual QA.

Reason: authoring dimensions and palette values belong to selected profiles, not to the universal identity of the design system.

### 2. A4 authoring section

Before, absence of a journal or reference figure automatically activated A4, Arial around 12 pt, an A4 proof, and cropped delivery.

After, those requirements activate only when A4 authoring is requested or `profiles/a4-working.yaml` is selected. Other workflows explicitly return `NOT_APPLICABLE` for these checks.

Reason: A4 is a conditional authoring profile, not a universal prerequisite for publication readiness.

### 3. Theme positioning

Before, the surrounding wording could make the executable A4/theme defaults appear to control the design system.

After, the selected visual, project, authoring, and journal profiles control the figure; the R file is explicitly described as render helpers and fallback implementation defaults.

Reason: the implementation order must remain:

```text
Visual Art Direction
→ Visual Profile
→ composition/design decisions
→ render helpers/theme
```

No R code was rewritten in this Gate.

### 4. Hard prohibition wording

Before, the anti-stretch rule referred specifically to occupying A4.

After, it applies to whichever authoring or delivery canvas is selected.

Reason: the design principle is canvas-independent.

### 5. Output contract

Before, every final figure appeared to require an A4 proof and cropped dimensions.

After, the universal contract requires the final deliverable, Source Data/provenance, scientific metadata, applicable formats, and all three QA statuses. A4 proof/crop and journal-specific artifacts are conditional.

Reason: a non-A4 workflow must not fail because an irrelevant proof is absent.

### 6. Visual art direction

Before, whitespace and fill behavior were expressed only relative to A4.

After, they refer to the selected authoring or delivery canvas.

Reason: visual rhythm is independent of a specific page size.

### 7. Delivery QA

Before, Delivery QA universally required A4 dimensions, crop dimensions, and Arial availability.

After, it checks the active profile's deliverable, dimensions/crop behavior, and font requirements. A4-specific checks run only under `a4-working`; otherwise they are `NOT_APPLICABLE`.

Reason: delivery checks must be profile-aware.

### 8. Visual QA

Before, typography PASS meant Arial around 12 pt on an A4 proof, and colour PASS meant using a fixed palette.

After, typography is judged by hierarchy, final-size legibility, and active-profile compliance. Colour is judged by profile consistency, semantics, accessibility, and scale/data compatibility.

Reason: Visual QA evaluates whether the visual design works, not whether a Potato-specific appearance was applied.

### 9. Three-source synthesis

Before, the shared workflow named only A4 or journal-final profiles and described fixed palette/A4 typography as the consistency layer.

After, it selects visual, authoring, and journal profiles independently; exact typography and colour values remain profile-specific.

Reason: the synthesis must reflect the frozen architecture rather than a legacy visual identity.

## Remaining keyword hits and why they are valid

| Location group | Classification | Why valid |
|---|---|---|
| `SKILL.md` conditional A4 section | `VALID_CONDITIONAL` | Explicitly activated only by the selected A4 authoring profile; non-A4 returns `NOT_APPLICABLE`. |
| `SKILL.md` generic accessible palette mention | `VALID_FALLBACK` | Explicitly named as fallback only. |
| `references/a4-layout-and-export.md` | `VALID_CONDITIONAL` | This entire reference defines one optional authoring profile. |
| `profiles/a4-working.yaml` | `VALID_CONDITIONAL` | Concrete A4 dimensions, Arial, proof, and crop settings belong to the A4 profile. |
| `profiles/high-impact-omics.yaml` and its benchmark | `VALID_PROFILE_SPECIFIC` | Arial/A4 preferences are frozen only inside the user-approved profile. |
| `references/color-system.md` | `VALID_FALLBACK` / `VALID_PROFILE_SPECIFIC` | Mandatory principles are separated from fallback and profile-specific values. |
| `themes/potato_theme_v02.R` generic constants/helpers | `VALID_FALLBACK` | `POTATO_JOURNAL_ACCESSIBLE`, `potato_theme()`, and Arial defaults are fallback render implementation. |
| `themes/potato_theme_v02.R` high-impact helpers | `VALID_PROFILE_SPECIFIC` | Called only by the corresponding approved profile. |
| `themes/potato_theme_v02.R` A4 export helper | `VALID_CONDITIONAL` | Existing implementation for the A4 authoring path; not documented as universal. |
| Nature 89/183 mm examples | `VALID_CONDITIONAL` | Journal-specific examples inside an override path, not universal dimensions. |

## Effect assessment

- Scientific logic: unchanged.
- Scientific audit and multiplicity logic: unchanged.
- Existing `high_impact_omics` profile values and layout: unchanged.
- A4 profile: retained unchanged.
- R render helper behavior: unchanged.
- Core architecture: unchanged.
- User-facing routing and QA semantics: clarified to be profile-aware.

## Independent consistency audit

| Check | Result |
|---|---|
| Potato Figure described as a unified theme | PASS — no |
| Universal fixed palette remains | PASS — no |
| A4 treated as mandatory for all figures | PASS — no |
| Visual QA uses Arial/A4/fixed palette as universal PASS criteria | PASS — no |
| Non-A4 workflow fails for missing A4 proof | PASS — no; check is `NOT_APPLICABLE` |
| Generic palette explicitly fallback | PASS |
| Profile palette confined to its profile | PASS |
| Theme explicitly only render helper/fallback | PASS |
| Scientific, delivery, and visual QA remain separate | PASS |
| Core architecture or scientific rules accidentally changed | PASS — no |

```text
universal_theme = FALSE
universal_palette = FALSE
universal_A4 = FALSE
profile_driven_visuals = TRUE
conditional_authoring_profile = TRUE
scientific_delivery_visual_QA_separated = TRUE
```
