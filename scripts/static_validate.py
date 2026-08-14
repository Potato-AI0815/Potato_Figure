#!/usr/bin/env python3
from __future__ import annotations
import csv, re, sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
errors=[]; warnings=[]; passes=[]

def check(cond, label, detail=""):
    (passes if cond else errors).append(f"{label}: {detail}".rstrip())

required = [
    "SKILL.md", "figure_contract_schema.md", "manifest_schema.md",
    "references/global-figure-state.md", "references/local-change-impact.md",
    "references/figure-assembly-contract.md", "references/potato-user-visual-profile.md",
    "references/figure-grammar-core.md", "references/grammars/single-cell.md",
    "profiles/potato-user-v1.yaml", "schemas/global_figure_state.example.yaml",
    "schemas/local_change_log.example.tsv", "schemas/global_coherence_qa_template.tsv",
    "schemas/impact_dependency_map.tsv", "scripts/lib/global_coherence_core.R",
    "scripts/audit_global_coherence.R", "scripts/check_change_impact.R",
    "scripts/evaluate_readiness.R", "tests/run_r4_tests.R"
]
for rel in required:
    check((ROOT/rel).is_file(), "required_file", rel)

# Lightweight YAML sanity without external dependencies.
def yaml_sanity(path: Path):
    text=path.read_text(encoding="utf-8")
    if "\t" in text:
        return False, "tab character present"
    stack=[]
    for n,line in enumerate(text.splitlines(),1):
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        indent=len(line)-len(line.lstrip(' '))
        if indent % 2:
            return False, f"odd indentation at line {n}"
        s=line.strip()
        if s.startswith('- '):
            continue
        if ':' not in s:
            return False, f"missing ':' at line {n}"
    return True, "basic key/indentation sanity"
for rel in ["profiles/potato-user-v1.yaml", "schemas/global_figure_state.example.yaml", "schemas/figure_contract.example.yaml"]:
    try:
        ok,detail=yaml_sanity(ROOT/rel); check(ok, "yaml_sanity", f"{rel}: {detail}")
    except Exception as e: errors.append(f"yaml_sanity: {rel}: {e}")

# TSV schemas
expected={
 "schemas/local_change_log.example.tsv": ["change_id","timestamp","change_type","target_key","reason","impact_scope","required_rechecks","recheck_status","global_state_updated","closed","notes"],
 "schemas/global_coherence_qa_template.tsv": ["domain","status","notes"],
 "schemas/impact_dependency_map.tsv": ["change_type","required_rechecks","description"],
}
for rel, cols in expected.items():
    try:
        with (ROOT/rel).open(encoding="utf-8", newline="") as f:
            got=next(csv.reader(f, delimiter="\t"))
        check(got==cols, "tsv_schema", f"{rel} -> {got}")
    except Exception as e: errors.append(f"tsv_schema: {rel}: {e}")

# Every repo-relative path mentioned in SKILL.md should exist.
skill=(ROOT/"SKILL.md").read_text(encoding="utf-8")
refs=set(re.findall(r'`((?:references|profiles|schemas|scripts|tests)/[^`\n ]+)', skill))
for rel in sorted(refs):
    rel=rel.rstrip('.,;:')
    if any(x in rel for x in ["/path/to/", "<"]):
        continue
    check((ROOT/rel).exists(), "skill_reference", rel)

# Parse flat YAML example used by the R flat parser.
def flat_yaml(path:Path):
    out={}
    for line in path.read_text(encoding='utf-8').splitlines():
        if not line.strip() or line.lstrip().startswith('#') or line.startswith(' '):
            continue
        m=re.match(r'^([A-Za-z0-9_.-]+):\s*(.*)$', line)
        if m:
            v=m.group(2).strip().strip('"\'')
            out[m.group(1)]=v
    return out
state=flat_yaml(ROOT/"schemas/global_figure_state.example.yaml")
required_state=[
 "state_version","figure_id","modality","assembly_mode","scientific.central_claim",
 "scientific.statistical_unit","narrative.reading_order","narrative.hero_panel","narrative.panel_tags",
 "visual.profile","visual.body_pt","visual.axis_text_pt","visual.panel_tag_pt",
 "geometry.target_width_occupancy","geometry.target_height_occupancy","geometry.outer_margin_mm",
 "geometry.panel_gap_mm","assembly.final_canvas","repair.change_log_file"
]
for k in required_state: check(k in state and state[k] != "", "global_state_field", k)

# Personal profile critical contract strings.
prof=(ROOT/"profiles/potato-user-v1.yaml").read_text(encoding="utf-8")
critical=[
    "target_width_occupancy: 0.88", "target_height_occupancy: 0.82",
    "ordinary_text_pt: [8.0, 12.0]", "matched_bar_width_across_comparable_panels: true",
    "neutral_data_ink_default: false", "panel_gap_mm: [2.5, 4.0]", "outer_margin_mm: [3.0, 4.0]"
]
for item in critical: check(item in prof, "profile_contract", item)

# R source static sanity: delimiter counts after removing comments/strings (heuristic, not R parser).
def strip_r(text:str)->str:
    out=[]
    for line in text.splitlines():
        buf=[]; quote=None; esc=False
        for ch in line:
            if esc:
                buf.append(' '); esc=False; continue
            if ch=='\\' and quote:
                esc=True; buf.append(' '); continue
            if quote:
                if ch==quote: quote=None
                buf.append(' '); continue
            if ch in ('"', "'"):
                quote=ch; buf.append(' '); continue
            if ch=='#': break
            buf.append(ch)
        out.append(''.join(buf))
    return '\n'.join(out)
for p in sorted((ROOT/"scripts").rglob("*.R")) + sorted((ROOT/"tests").rglob("*.R")):
    s=strip_r(p.read_text(encoding="utf-8"))
    for a,b in [('(',')'),('[',']'),('{','}')]:
        if s.count(a)!=s.count(b): errors.append(f"r_delimiter_balance: {p.relative_to(ROOT)} {a}{b} {s.count(a)}!={s.count(b)}")
    passes.append(f"r_static_scan: {p.relative_to(ROOT)}")

check("single-cell" in skill.lower() and "adapter" in skill.lower() and "modality-agnostic" in skill.lower(), "core_adapter_boundary")
check("local change" in skill.lower() and "global figure state" in skill.lower(), "global_local_core_present")

print(f"STATIC_VALIDATION passes={len(passes)} warnings={len(warnings)} errors={len(errors)}")
for x in errors: print("ERROR", x)
for x in warnings: print("WARNING", x)
if errors: sys.exit(1)
print("STATIC_VALIDATION: PASS")
