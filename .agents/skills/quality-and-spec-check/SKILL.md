---
name: quality-and-spec-check
description: Use when checking whether a project's code or config follows general code quality rules and project-specific rules defined in a spec document. Trigger on "quality check", "spec check", "compliance check", "does this follow the spec", or code review/PR checks that require comparing against a spec doc.
---

# Spec Compliance Check

Verify a project complies with rules in a spec document.

## Steps

1. **Load spec**: read the spec document path provided by the user. If missing, ask for it.
2. **Extract rules**: pull verifiable rules from the spec into a checklist (naming conventions, required files/folders, forbidden patterns, required API formats, etc.)
3. **Scan project**: check code/config against each rule.
4. **Report**:

| Rule | Status | Evidence (file:line) | Note |
|---|---|---|---|
| rule name | ✅/❌ | path/to/file:12 | fix suggestion if failed |

End with a summary of violations, prioritized (critical/minor).

## Code Quality Check

In addition to spec rules, flag violations of these core principles:

- **SRP**: a function/class does one thing
- **DRY**: no duplicated logic
- **Naming**: names reveal intent, no abbreviations/magic numbers
- **Function size**: small, single level of abstraction
- **Dependency direction**: depend on abstractions, not concretions (DIP)
- **Open/Closed**: extend without modifying existing code
- **Comments**: remove obvious comments, because good code explains itself
- **Dead code / commented-out code**: none left in

Report these in the same table format as spec rules, under a separate "Code Quality" section.

