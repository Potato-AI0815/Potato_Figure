# Deferred issues after R0

The following items were observed or already known but are outside the Legacy Residue Cleanup Gate. None was implemented.

1. Reintegrate the mature v0.1.5 scientific/delivery audit execution layer while keeping Visual QA separate.
2. Add CI for the rebuilt v0.2 package after the execution layer is defined.
3. Run a future blind benchmark comparing the legacy workflow with the rebuilt design kernel.
4. Add further visual profiles only after the user supplies and approves real visual references; do not invent clinical or image-led profiles.
5. Review render-helper naming and scope: the generic `save_potato_figure()` name currently wraps A4-specific behavior and may need an explicit A4 name or a profile dispatcher in a later Gate.
6. Add future journal profiles only after verifying current official journal instructions.


## R4 deferred issues

- ~~R4 runtime tests are included but were not executed~~ — RESOLVED: R4
  regression now runs and passes 4/4 (see RUNTIME_VALIDATION_REPORT.md);
  full release validation is executed in CI/release gates.
- The dependency map is intentionally rule-based and coarse; it is not a universal causal graph inferred from pixels.
- `potato-user-v1` is a personal evidence-backed profile, not a journal standard and not a universal aesthetic default for other users.
- Only the single-cell modality adapter is explicitly documented in this patch. Additional IHC/clinical/WB/animal adapters should be added only after real use cases, not pre-generated from theory.
- Automated pixel-level measurement of bar-width consistency, blank-area fraction and panel bounding boxes remains future work; R4 currently makes these explicit render-review obligations rather than pretending they are fully automated.
