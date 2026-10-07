# nf-core/bamtofastq roadmap

**Last revised:** 2026-10-07  
**Current release:** 2.2.1  
**Branch:** `2.3.0dev`

## Ground rules

- One theme per release; file budget default **&lt; 100 changed files** per release.
- Breaking changes batch into the next **major**.
- Tag legend: `#n` = GitHub issue or PR on nf-core/bamtofastq.
- Never update nf-test snapshots unless a test is red for a reason that requires it.

## Overview

| Release | Theme | Type | Est. files |
| ------- | ----- | ---- | ---------- |
| **2.3.0** | `--references` datasheet as alternative to iGenomes (coexist) | minor | ~12 |
| 2.4.0 | Hardening / docs after datasheet ships | minor | ~10 |
| **3.0.0** | Drop iGenomes config, params, and `getGenomeAttribute` | major | ~8 |

## 2.3.0 — Coming release

**Goal.** Two ways to supply a reference, both live:

1. **iGenomes catalogue** — `--genome` + `conf/igenomes.config`
2. **`--references`** — YAML datasheet from [nf-core/references-datasheets](https://github.com/nf-core/references-datasheets)

They **coexist**. Catalogue drop is 3.0.0 only.

*Note:* `#149` (test profile via iGenomes test genome keys) is in review and expected to merge; it is not planned as roadmap work here.

### `--references` datasheet

| Piece | Design |
| ----- | ------ |
| Param | `--references` — path/URL to YAML (`file-path`, `\.(yaml\|yml)$`) |
| Schema | `assets/schema_references.json` — **subset** of nf-core/references `schema_references.json` |
| Fields | Required: `genome`. Files: `fasta`, `fasta_fai`. Meta: `site`, `source`, `source_version`, `species`, `readme`. Same `meta: [...]` conventions as upstream |
| Extra keys | Ignored (datasheets stay compatible) |
| Multi-record YAML | `--genome` selects; if required and missing, error listing available `genome` values |
| Resolution | `main.nf` (same place as `getGenomeAttribute` + FAIDX branch) |
| Output | `[meta, fasta, fai]` or empty for `BAMTOFASTQ` |

**Precedence (highest first).**

1. Explicit `--fasta` / `--fasta_fai`
2. `--references` datasheet (`--genome` picks record if multi)
3. iGenomes catalogue (`--genome` + `getGenomeAttribute`)
4. Empty reference

**Coexistence.**

- `--references` and iGenomes are independent.
- If both resolve a reference, datasheet wins (CLI still wins over both).
- No `igenomes_ignore` required when using `--references`.
- At least one test or documented CLI example uses a datasheet; existing tests may keep iGenomes.

**Docs.** Usage: datasheet example (references-datasheets raw URL), precedence table, iGenomes still supported in 2.3.0.

**Out of scope.** `references_base_path`, per-sample genome column, `s3://nf-core-references` bundles, MultiQC meta from datasheet.

**Done when.**

- `nextflow run . --references <datasheet.yml> --outdir ...` works.
- Explicit `--fasta` overrides datasheet and iGenomes.
- iGenomes `--genome` still works without `--references`.
- `prek` / lint clean on changed files; CHANGELOG updated.

## 2.4.0 — Hardening

- Datasheet gaps found in the field (schema, errors).
- Optional: datasheet meta on MultiQC / `pipeline_info` if not in 2.3.0.
- Docs: pin references-datasheets by commit.
- No iGenomes removal.

## 3.0.0 — Drop iGenomes

- Remove `params.genome`, `params.igenomes_base`, `params.igenomes_ignore`.
- Remove `getGenomeAttribute` / `genomeExistsError`.
- Drop `igenomes_*` from `nextflow_schema.json`; remove or rewrite `genome`.
- Stop including `conf/igenomes.config` / `igenomes_ignored.config`.
- AWS anonymous client keyed off reference path prefixes, not `igenomes_ignore`.
- Migration: `--references` or explicit `--fasta`/`--fasta_fai`.

**Blocked on.** 2.3.0 in the wild; test profile not dependent on iGenomes keys (or those keys move into datasheets); docs updated.

## Backlog

| Item | Notes |
| ---- | ----- |
| #145 Use full path to the tool in the config files | Independent |
| #136 Mapping to chromosomes functionality? | Needs scoping; `--chr` exists |
| #121 Evaluate alternatives for transforming bams to fastqs | Research |
| #117 Remove params from all scripts except root `main.nf` | Resolution stays in `main.nf` for 2.3.0 |
| #106 Pipeline fails when too many chromosomes/regions | Bug |
| #86 MultiQC error with test profile using kubernetes | Infra |
| #18 Replace some samtools command with seqkit | Research |
| #146 Why FASTQC only on BAM files? | Behaviour question |

## Traceability

| Source | Release |
| ------ | ------- |
| `--references` datasheet (coexist with iGenomes) | 2.3.0 |
| Drop iGenomes | 3.0.0 |
| #145, #136, #121, #117, #106, #86, #18, #146 | Backlog |

## Decisions log

- **2026-10-06** — Datasheet design paused; subset schema agreed (genome, fasta, fasta_fai, site, source, source_version, species, readme).
- **2026-10-06** — Multi-record datasheets: `--genome` selects; error lists names when selection required.
- **2026-10-07** — nf-test does not expose config-file params inside a test `params` block when evaluating `input = params....`.
- **2026-10-07** — **`--references` ships in 2.3.0 as an alternative to iGenomes; both coexist.** Precedence: explicit fasta/fai > datasheet > iGenomes catalogue > empty. iGenomes drop deferred to 3.0.0.
- **2026-10-07** — Schema stays a **subset** of nf-core/references `schema_references.json`.

## Open questions

- Datasheet coverage in 2.3.0: dedicated `nf-test` with a `genomes_source` URL, or documented CLI example only?
- Put `--references` in `nextflow_schema.json` under `reference_genome_options` next to `genome`/`fasta`?
- Snapshot policy for any datasheet test: update in-PR or only if CI is red?
