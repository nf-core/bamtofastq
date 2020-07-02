# ![qbic-pipelines/bamtofastq](docs/images/qbic-pipelines-bamtofastq_logo.png)

**Workflow converts one or multiple bam files back to the fastq format**.

[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A50.32.0-brightgreen.svg)](https://www.nextflow.io/)
[![nf-core](https://img.shields.io/badge/nf--core-pipeline-brightgreen.svg)](https://nf-co.re/)

[![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg)](http://bioconda.github.io/)
[![Docker](https://img.shields.io/docker/automated/nfcore/bamtofastq.svg)](https://hub.docker.com/r/nfcore/bamtofastq)

[![GitHub Actions CI status](https://github.com/qbic-pipelines/bamtofastq/workflows/nf-core%20CI/badge.svg)](https://github.com/qbic-pipelines/bamtofastq/actions?query=workflow%3A%22qbic-pipelines+CI%22)
[![GitHub Actions Linting status](https://github.com/qbic-pipelines/bamtofastq/workflows/nf-core%20linting/badge.svg)](https://github.com/qbic-pipelines/bamtofastq/actions?query=workflow%3A%22qbic-pipelines+linting%22)
## Introduction

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It comes with docker containers making installation trivial and results highly reproducible.

## Quick Start

i. Install [`nextflow`](https://nf-co.re/usage/installation)

ii. Install one of [`docker`](https://docs.docker.com/engine/installation/), [`singularity`](https://www.sylabs.io/guides/3.0/user-guide/) or [`conda`](https://conda.io/miniconda.html)

iii. Download the pipeline and test it on a minimal dataset with a single command

```bash
nextflow run qbic-pipelines/bamtofastq -profile test,<docker/singularity/conda>
```

iv. Start running your own analysis!

```bash
nextflow run qbic-pipelines/bamtofastq -profile <docker/singularity/conda> --input '*.bam' 
```

See [usage docs](docs/usage.md) for all of the available options when running the pipeline.

## Documentation

The qbic-pipelines/bamtofastq pipeline comes with documentation about the pipeline, found in the `docs/` directory:

1. [Installation](https://nf-co.re/usage/installation)
2. Pipeline configuration
    * [Local installation](https://nf-co.re/usage/local_installation)
    * [Adding your own system config](https://nf-co.re/usage/adding_own_config)
    * [Reference genomes](https://nf-co.re/usage/reference_genomes)
3. [Running the pipeline](docs/usage.md)
4. [Output and how to interpret the results](docs/output.md)
5. [Troubleshooting](https://nf-co.re/usage/troubleshooting)

<!-- TODO nf-core: Add a brief overview of what the pipeline does and how it works -->

## Credits

nf-core/bamtofastq was originally written by Friederike Hanssen.

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on [Slack](https://nfcore.slack.com/channels/nf-core/bamtofastq) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citation

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi. -->
<!-- If you use  nf-core/bamtofastq for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

You can cite the `nf-core` pre-print as follows:  
Ewels PA, Peltzer A, Fillinger S, Alneberg JA, Patel H, Wilm A, Garcia MU, Di Tommaso P, Nahnsen S. **nf-core: Community curated bioinformatics pipelines**. *bioRxiv*. 2019. p. 610741. [doi: 10.1101/610741](https://www.biorxiv.org/content/10.1101/610741v1).
