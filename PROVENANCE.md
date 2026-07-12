# Provenance for the v0.1.0 initial-submission snapshot

This record separates the successful full-data execution from later portability and repository-maintenance changes. The existing full-run PDF is not represented as a byte-for-byte render of the later canonical source.

## Successful full-data run

| Item | Value |
|---|---|
| Wrapper run | `20260629_074952` |
| Notebook run ID | `20260629_075007` |
| Recorded repository commit at run time | `10ebba80dc6a0adfb39592afc34f54ae4b2089c4` |
| Recorded worktree state at run time | dirty, 440 entries |
| Exact executed QMD SHA-256 | `f77d21aab5e28c34c4e9e19640758237269154d54831cc2de761c07a58170daf` |
| Final full-run PDF SHA-256 | `bc23e1569c4abf5b4989d65d7ffb9868330bc24cfac4fec7ce58c9fbe9e60420` |

The exact executed QMD was recovered from the successful run's clean output archive and is preserved in the `v0.1.0` review bundle as `executed-source/ABG-VBG-analysis-20260629.qmd`. Because the run-time worktree was dirty, the recorded Git commit alone is not sufficient to reconstruct the executed source.

## Source lineage after the full render

| Source state | SHA-256 | Relationship to the successful full run |
|---|---|---|
| Exact executed QMD | `f77d21aab5e28c34c4e9e19640758237269154d54831cc2de761c07a58170daf` | Source that produced the retained full-run PDF |
| Post-review dated QMD | `2d8d93be8e93072dfa17d8a6d70cb7e54aa8a2d40b461c71f5bc68b163be2a0b` | Post-render ticket-reference and packaging portability changes |
| Canonical release QMD | `e26ed760228e37480e91a4c02a36faef768302a06d6731007f18999129ee619c` | Stable-path, self-contained release source |

The changes from the executed QMD to the post-review dated QMD were reviewed as non-analytical: they made ticket references repository-local, changed missing/fallback ticket traceability from blocking analytical failures to review warnings, and generalized packaging/duplicate-render checks. They did not alter estimands, model specifications, data transformations, seeds, or manuscript-facing numerical outputs.

The canonical release QMD promotes that dated source to `Code Drafts/ABG-VBG-analysis.qmd`, replaces the runtime checksum dependency on older notebooks with static lineage metadata, and inlines the existing diagnostics-audit implementation. The inlined diagnostics body was checked against the former helper implementation. These are portability and repository-maintenance changes, not claims that the retained full-run PDF was regenerated.

## Release validation contract

- The retained 423-page full-run PDF and selected manuscript-facing artifacts come from run `20260629_075007`.
- A canonical 1% pilot validates that the released self-contained QMD executes top-to-bottom with its current wrapper and checks. It does not replace or recompute the full-data release results.
- Release assets include file-level SHA-256 checksums, a content manifest, sanitized run metadata, and the exact executed-source snapshot.
- Ticket snapshots under `Code Drafts/ticket_snapshots/` are post-hoc implementation and traceability records. They are not preregistration documents.
- Restricted data, the governed codebook, model state, per-imputation outputs, logs, manuscript drafts, and correspondence are excluded from the public repository and release.

## Release environment

The release validation environment used R 4.5.3, Quarto 1.8.26, Pandoc 3.6.3, and LuaHBTeX 1.22.0 from TeX Live 2025. Package versions are resolved by `renv.lock`; `DESCRIPTION` declares the direct dependencies used by the canonical source.
