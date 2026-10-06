# nf-core/bamtofastq roadmap

**Last revised:** 2026-10-06  
**Current release:** 2.2.1  
**`dev` / `feat/references` holds:** 2.3.0dev — template updates for nf-core/tools v4.0.3 and v4.1.0, `manifest.diagram`, and an in-progress removal of the iGenomes catalogue (`conf/igenomes.config`, `conf/igenomes_ignored.config`, and the `includeConfig` that loaded them).

## Ground rules

- One theme per release; file budget default **&lt; 100 changed files** per release.
- Breaking changes (removed/renamed params, samplesheet column changes, output structure changes) batch into the next **major**.
- External gates (modules in nf-core/modules, test data in nf-core/test-datasets) are PR 0 and do not count against the budget.
- Tag legend: `#n` = GitHub issue or PR on nf-core/bamtofastq.
- Never update nf-test snapshots unless a test is red for a reason that requires it.

## Overview

| Release | Theme                                                  | Type  | Est. files | Gated by                                      |
| ------- | ------------------------------------------------------ | ----- | ---------- | --------------------------------------------- |
| 2.3.0   | Prepare-reference split + iGenomes catalogue removal   | minor | ~15        | none                                          |
| 2.4.0   | `--references` datasheet input (references-datasheets) | minor | ~12        | nf-core/references-datasheets raw URLs stable |
| 3.0.0   | Drop dead iGenomes params / genome lookup helpers      | major | ~8         | 2.4.0 released; docs migrated                 |

## 2.3.0 — Prepare-reference split + iGenomes removal

**Goal.** Keep `BAMTOFASTQ` focused on conversion: index BAM/CRAM only when missing, via `SAMTOOLS_INDEX` called directly from the workflow. Move FASTA index generation into a dedicated `PREPARE_REFERENCE` subworkflow invoked outside `workflows/bamtofastq.nf`.

**Why.** `PREPARE_INDICES` currently couples two unrelated jobs (alignment indexing + reference FAI generation). FAI generation belongs with reference preparation, not with the conversion workflow, and will be the hook for future datasheet-driven references.

### Contract after 2.3.0

| Input                           | Behaviour                                                                                                                 |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| BAM/CRAM + index                | Used as-is; no `SAMTOOLS_INDEX` run                                                                                       |
| BAM/CRAM without index          | `SAMTOOLS_INDEX` runs inline in `BAMTOFASTQ`                                                                              |
| `--fasta` without `--fasta_fai` | `PREPARE_REFERENCE` runs `SAMTOOLS_FAIDX`, emits `[meta, fasta, fai]`                                                     |
| `--fasta` + `--fasta_fai`       | Emitted as provided; no `SAMTOOLS_FAIDX`                                                                                  |
| No `--fasta`                    | Empty reference channel (`[meta:'none', [], []]`); conversion proceeds                                                    |
| `--genome` + iGenomes catalogue | **No longer resolves** — `conf/igenomes*.config` removed; `getGenomeAttribute` / `genomeExistsError` are dead until 3.0.0 |

### PR plan

| PR  | Content                                                                                                                                                                                         | Est. files |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| A   | Checkpoint: iGenomes config removal + this roadmap                                                                                                                                              | 5          |
| B   | `subworkflows/local/prepare_reference/` (main.nf, meta.yml, tests); call from `main.nf`; `BAMTOFASTQ` takes prepared `fasta_fai`; inline `SAMTOOLS_INDEX`; delete `prepare_indices/`; CHANGELOG | ~12        |

**Done when.** `nextflow run . -profile test,docker` passes; `nf-test test subworkflows/local/prepare_reference` passes; no `PREPARE_INDICES` references remain; `prek` clean; CHANGELOG updated.

## 2.4.0 — `--references` datasheet input

**Goal.** Accept a YAML datasheet from [nf-core/references-datasheets](https://github.com/nf-core/references-datasheets) via `--references`, providing `fasta`, `fasta_fai` and meta (`genome`, `site`, `source`, `source_version`, `species`).

**Contract.**

- New `assets/schema_references.json`: subset of nf-core/references `schema_references.json` (same `meta` conventions; required `genome`; optional `fasta` / `fasta_fai` / meta fields). Extra keys in datasheets are ignored.
- New param `--references` (`file-path`, schema-validated YAML).
- Precedence: `--fasta`/`--fasta_fai` → `--references` (record chosen by `--genome` if multi-record) → empty reference.
- `PREPARE_REFERENCE` consumes the resolved `[meta, fasta, fai]`; FAI still auto-built when absent.
- `conf/test_full.config` switches from a hard-coded iGenomes FASTA to a references-datasheets URL.
- Docs: usage section with examples and precedence; note relationship to nf-core/references 1.0.0 `params.yml` plan.

**Not in 2.4.0.** Path rewriting (`references_base_path`), per-sample genome column, consumption of built bundles under `s3://nf-core-references`.

## 3.0.0 — Remove dead iGenomes surface

**Goal.** Delete residual iGenomes API once datasheets are the documented path.

- Remove `params.genome` (as iGenomes key), `params.igenomes_base`, `params.igenomes_ignore`.
- Remove `getGenomeAttribute` / `genomeExistsError` from `main.nf` and `utils_nfcore_bamtofastq_pipeline`.
- Drop `igenomes_*` blocks from `nextflow_schema.json`; rewrite `genome` help text or remove the param.
- AWS anonymous client keyed off reference path prefixes (`s3://ngi-igenomes/`, `s3://nf-core-references/`) instead of `igenomes_ignore`.
- Migration note in CHANGELOG and usage docs.

**Blocked on.** 2.4.0 released; open PR #149 (test profile fasta) resolved or superseded.

## Backlog

| Item                                                       | Notes                                                                |
| ---------------------------------------------------------- | -------------------------------------------------------------------- |
| #149 Fix test profile to contain fasta reference           | Open PR; overlaps 2.3.0 test profile work — merge or rebase onto B   |
| #145 Use full path to the tool in the config files         | Independent of references work                                       |
| #136 Mapping to chromosomes functionality?                 | Needs scoping; `--chr` already exists — clarify gap                  |
| #121 Evaluate alternatives for transforming bams to fastqs | Research; do not block 2.3.0/2.4.0                                   |
| #117 Remove params from all scripts except root `main.nf`  | Aligns with passing paths into `PREPARE_REFERENCE` as `take:` inputs |
| #106 Pipeline fails when too many chromosomes/regions      | Bug; fix before or with any `--chr` docs rewrite                     |
| #86 MultiQC error with test profile using kubernetes       | Infra-specific                                                       |
| #18 Replace some samtools command with seqkit              | Research; out of scope for references releases                       |
| #146 Why FASTQC only on BAM files?                         | Behaviour question; unrelated to references                          |

## Traceability

| Source                                                                                         | Release                       |
| ---------------------------------------------------------------------------------------------- | ----------------------------- |
| Branch WIP `feat/references` (iGenomes config removal)                                         | 2.3.0 PR A                    |
| Prepare-reference refactor (maintainer agenda 2026-10-06)                                      | 2.3.0 PR B                    |
| References datasheet schema + `--references` (maintainer agenda 2026-10-06; paused mid-design) | 2.4.0                         |
| Dead iGenomes param removal                                                                    | 3.0.0                         |
| #149                                                                                           | 2.3.0 / backlog until rebased |
| #145, #136, #121, #117, #106, #86, #18, #146                                                   | Backlog                       |

## Decisions log

- **2026-10-06** — References datasheet work paused after design review; checkpoint branch state before refactor.
- **2026-10-06** — iGenomes catalogue configs removed on `feat/references`; `params.genome` / `igenomes_*` / lookup helpers left in place until 3.0.0 for retro-compatibility.
- **2026-10-06** — FAI generation moves to `PREPARE_REFERENCE`, called outside `BAMTOFASTQ`; `PREPARE_INDICES` dropped; `SAMTOOLS_INDEX` only when BAM/CRAM index is missing.
- **2026-10-06** — `assets/schema_references.json` will be a **subset** of nf-core/references `schema_references.json` (genome, fasta, fasta_fai, site, source, source_version, species, readme), not a full copy.
- **2026-10-06** — Multi-record datasheets: `--genome` selects the record; error lists available names when selection is required but missing.
- **2026-10-06** — Datasheet resolution precedence: explicit `--fasta`/`--fasta_fai` > `--references` > empty reference. iGenomes lookup is not part of this chain once configs are gone.

## Open questions

- Should `conf/igenomes.config` be restored on `dev` until 3.0.0, or is config removal + dead params acceptable for 2.3.0? (Branch currently removes the configs.)
- Do we want `PREPARE_REFERENCE` to emit richer meta (`genome`, `source`, `species`) in 2.3.0, or only in 2.4.0 when datasheets land?
- Is PR #149 still needed if 2.3.0 PR B updates the test profile / `conf/test_full.config`?
