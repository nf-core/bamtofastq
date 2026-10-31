#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
nf-core/bamtofastq
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Github : https://github.com/nf-core/bamtofastq
Website: https://nf-co.re/bamtofastq
Slack  : https://nfcore.slack.com/channels/bamtofastq
----------------------------------------------------------------------------------------
 */

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 */

include { getReferenceAttribute } from 'plugin/nf-core-utils'
include { samplesheetToList } from 'plugin/nf-schema'

include { BAMTOFASTQ } from './workflows/bamtofastq'
include { SAMTOOLS_FAIDX } from './modules/nf-core/samtools/faidx'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_bamtofastq_pipeline'
include { PIPELINE_COMPLETION } from './subworkflows/local/utils_nfcore_bamtofastq_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 */

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow NFCORE_BAMTOFASTQ {
    take:
    samplesheet // channel: samplesheet read in from --input
    datasheet // channel: datasheet read in from direct yml or via genome key

    main:
    // REFERENCES: Resolve attributes from datasheet
    params.fasta = getReferenceAttribute(param: 'fasta', datasheet: datasheet, genomeMap: params.genomes, genomeKey: params.genome)
    params.fasta_fai = getReferenceAttribute(param: 'fasta_fai', datasheet: datasheet, genomeMap: params.genomes, genomeKey: params.genome)

    // [meta, fasta, fai] for the run; empty when no reference
    if (!params.fasta) {
        ch_references = channel.empty()
    }
    else if (params.fasta_fai) {
        ch_references = channel.fromPath(params.fasta)
            .collect()
            .combine(channel.fromPath(params.fasta_fai))
            .map { fa, fai -> [[id: fa.baseName], fa, fai] }
            .collect()
    }
    else {
        SAMTOOLS_FAIDX(channel.fromPath(params.fasta).map { fa -> [[id: fa.baseName], fa, []] }, false)
        ch_references = channel.fromPath(params.fasta)
            .combine(SAMTOOLS_FAIDX.out.fai.map { _meta, fai -> fai })
            .map { fa, fai -> [[id: fa.baseName], fa, fai] }
            .collect()
    }

    //
    // WORKFLOW: Run pipeline
    //
    BAMTOFASTQ(
        samplesheet,
        ch_references,
        params.multiqc_config,
        params.multiqc_logo,
        params.multiqc_methods_description,
        params.outdir,
    )

    emit:
    multiqc_report = BAMTOFASTQ.out.multiqc_report // channel: /path/to/multiqc_report.html
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 */

workflow {
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION(
        params.version,
        params.validate_params,
        args,
        params.outdir,
        params.input,
        params.help,
        params.help_full,
        params.show_hidden,
        params.monochrome_logs,
    )

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_BAMTOFASTQ(
        PIPELINE_INITIALISATION.out.samplesheet,
        PIPELINE_INITIALISATION.out.datasheet.getVal(),
    )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION(
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        NFCORE_BAMTOFASTQ.out.multiqc_report,
    )
}
