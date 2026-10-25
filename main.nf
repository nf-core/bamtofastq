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

include { samplesheetToList       } from 'plugin/nf-schema'

params.fasta     = getReferenceAttribute('fasta')
params.fasta_fai = getReferenceAttribute('fasta_fai')

include { BAMTOFASTQ              } from './workflows/bamtofastq'
include { SAMTOOLS_FAIDX          } from './modules/nf-core/samtools/faidx'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_bamtofastq_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_bamtofastq_pipeline'

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

    main:
    def reference = [fasta: params.fasta, fasta_fai: params.fasta_fai]

    // [meta, fasta, fai] for the run; empty when no reference
    if (!reference.fasta) {
        ch_references = channel.empty()
    }
    else if (reference.fasta_fai) {
        ch_references = channel.fromPath(reference.fasta)
            .collect()
            .combine(channel.fromPath(reference.fasta_fai))
            .map { fasta, fasta_fai -> [[id: fasta.baseName], fasta, fasta_fai] }
            .collect()
    }
    else {
        SAMTOOLS_FAIDX(channel.fromPath(reference.fasta).map { fasta -> [[id: fasta.baseName], fasta, []] }, false)
        ch_references = channel.fromPath(reference.fasta)
            .combine(SAMTOOLS_FAIDX.out.fai.map { _meta, fasta_fai -> fasta_fai })
            .map { fasta, fasta_fai -> [[id: fasta.baseName], fasta, fasta_fai] }
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
        PIPELINE_INITIALISATION.out.samplesheet
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

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Get reference attributes by resolving from the highest-priority source.
// The plugin provides the precedence logic and helper functions;
// we provide the datasheet loader that calls samplesheetToList (pipeline-only).
//

def getReferenceAttribute(String name) {
    // Can't access plugin static methods directly in Groovy Nextflow scripts.
    // Instead, inline the orchestration logic here but delegate to plugin helpers.
    def genome = params.genome in [null, 'null'] ? null : params.genome
    if (params.references && genome) {
        error("Use either --references or --genome, not both.")
    }
    def sheet = [:]
    if (params.references) {
        sheet = loadDatasheetFile(params.references)
    } else if (genome && params.igenomes_ignore) {
        sheet = loadDatasheetFile(referencesDatasheetUrl(genome))
    }
    return sheet[name] ?: getGenomeAttribute(name)
}

def referencesDatasheetUrl(String genomeKey) {
    def base = (params.references_datasheets_path ?: '').toString().replaceAll(/\/+$/, '')
    if (!base) {
        error("--references_datasheets_path is empty; cannot load datasheet for --genome '${genomeKey}'")
    }
    return "${base}/${genomeKey}.yml"
}

def selectReferenceRow(List rows) {
    if (!(rows instanceof List) || rows.isEmpty()) {
        error("Reference datasheet did not contain any genome records")
    }
    if (rows.size() > 1) {
        def names = rows.collect { row -> referenceMeta(row).genome }.findAll { name -> name }
        error("Reference datasheet has multiple genomes (${names.join(', ')}). Use a datasheet with one genome record.")
    }
    return rows[0]
}

def referenceMeta(row) {
    if (row instanceof Map) {
        return row
    }
    if (row instanceof List && row && row[0] instanceof Map) {
        return row[0]
    }
    return [:]
}

def getGenomeAttribute(String attribute) {
    if (params.genomes && params.genome && params.genomes.containsKey(params.genome)) {
        if (params.genomes[params.genome].containsKey(attribute)) {
            return params.genomes[params.genome][attribute]
        }
    }
    return null
}

//
// Load a reference datasheet from a file path.
// This stays in the pipeline because it must call samplesheetToList(),
// which is a workflow-level function from nf-schema and only available in pipeline context.
//

def loadDatasheetFile(String path) {
    def rows = samplesheetToList(path, "${projectDir}/assets/schema_references.json")
    def row = selectReferenceRow(rows)
    def meta = referenceMeta(row)
    return meta.findAll { _key, value -> value != null && value != '' }
}
