<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/nf-core-bamtofastq_logo_dark.png">
    <img alt="nf-core/bamtofastq" src="docs/images/nf-core-bamtofastq_logo_light.png">
  </picture>
</h1>

[![GitHub Actions CI Status](https://github.com/nf-core/bamtofastq/actions/workflows/ci.yml/badge.svg)](https://github.com/nf-core/bamtofastq/actions/workflows/ci.yml)
[![GitHub Actions Linting Status](https://github.com/nf-core/bamtofastq/actions/workflows/linting.yml/badge.svg)](https://github.com/nf-core/bamtofastq/actions/workflows/linting.yml)[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/bamtofastq/results)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://tower.nf/launch?pipeline=https://github.com/nf-core/bamtofastq)

[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23bamtofastq-4A154B?labelColor=000000&logo=slack)](https://nfcore.slack.com/channels/bamtofastq)[![Follow on Twitter](http://img.shields.io/badge/twitter-%40nf__core-1DA1F2?labelColor=000000&logo=twitter)](https://twitter.com/nf_core)[![Follow on Mastodon](https://img.shields.io/badge/mastodon-nf__core-6364ff?labelColor=FFFFFF&logo=mastodon)](https://mstdn.science/@nf_core)[![Watch on YouTube](http://img.shields.io/badge/youtube-nf--core-FF0000?labelColor=000000&logo=youtube)](https://www.youtube.com/c/nf-core)

## Introduction

**nf-core/bamtofastq** is a bioinformatics best-practice analysis pipeline that converts (un)mapped `.bam` or `.cram` files into `fq.gz` files. Initially, it auto-detects, whether the input file contains single-end or paired-end reads. Following this step, the reads are sorted using `samtools collate` and extracted with `samtools fastq`. Furthermore, for mapped bam/cram files it is possible to only convert reads mapping to a specific region or chromosome. The obtained FastQ files can then be used to further process with other pipelines.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. Where possible, these processes have been submitted to and installed from [nf-core/modules](https://github.com/nf-core/modules) in order to make them available to all nf-core pipelines, and to everyone within the Nextflow community!

On release, automated continuous integration tests run the pipeline on a full-sized dataset on the AWS cloud infrastructure. This ensures that the pipeline runs on AWS, has sensible resource allocation defaults set to run on real-world datasets, and permits the persistent storage of results to benchmark between pipeline releases and other analysis sources.The results obtained from the full-sized test can be viewed on the [nf-core website](https://nf-co.re/bamtofastq/results).

## Pipeline summary

By default, the pipeline currently performs the following steps:

1. Quality control (QC) of input (bam/cram) files ([`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)).
2. Check if input files are single- or paired-end ([`Samtools`](https://www.htslib.org/)).
3. Compute statistics on input files ([`Samtools`](https://www.htslib.org/)).
4. Convert to fastq reads ([`Samtools`](https://www.htslib.org/)).
5. QC of converted fastq reads ([`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)).
6. Summarize QC and statistics before and after format conversion ([`MultiQC`](http://multiqc.info/)).

<p align="center">
    <img title="Bamtofastq Workflow" src="docs/images/nf-core-bamtofastq-subway.png" width=60%>
</p>

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

Download the pipeline and test it on a minimal dataset with a single command:

```bash
nextflow run nf-core/bamtofastq -profile test,<docker/singularity/.../institute> --outdir './results'
```

To run your own analysis, start by preparing a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample_id,mapped,index,file_type
test,test1.bam,test1.bam.bai,bam
test2,test2.bam,test2.bam.bai,bam
```

Each row represents a bam/cram file with or without indices.

Now, you can run the pipeline using:

```bash
nextflow run nf-core/bamtofastq \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.csv \
   --outdir <OUTDIR>
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;
> see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

For more details and further functionality, please refer to the [usage documentation](https://nf-co.re/bamtofastq/usage) and the [parameter documentation](https://nf-co.re/bamtofastq/parameters).

## Pipeline output

To see the results of an example test run with a full size dataset refer to the [results](https://nf-co.re/bamtofastq/results) tab on the nf-core website pipeline page.
For more details about the output files and reports, please refer to the
[output documentation](https://nf-co.re/bamtofastq/output).

## Credits

nf-core/bamtofastq was originally written by Friederike Hanssen. It was ported to DSL2 by Susanne Jodoin.

We thank the following people for their extensive assistance in the development of this pipeline:

- [Gisela Gabernet](https://github.com/ggabernet)
- [Matilda Åslin](https://github.com/matrulda)
- [Bruno Grande](https://github.com/BrunoGrandePhd)

### Resources

The individual steps of this pipeline are based of on the following tutorials and resources:

1.  [Extracting paired FASTQ read data from a BAM mapping file](http://darencard.net/blog/2017-09-07-extract-fastq-bam/)
2.  [Check if BAM is derived from pair-end or single-end reads](https://www.biostars.org/p/178730/)

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#bamtofastq` channel](https://nfcore.slack.com/channels/bamtofastq) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

If you use nf-core/bamtofastq for your analysis, please cite it using the following doi: [10.5281/zenodo.4710628](https://doi.org/10.5281/zenodo.4710628)

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
