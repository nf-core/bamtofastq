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
    def reference = resolveReference()

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
// Resolve reference meta from the first source that provides a usable record.
// Sources may contribute any subset of keys (fasta, fasta_fai, genome, species, ...).
// Precedence: explicit params > --references > --genome+igenomes_ignore datasheet > iGenomes.
// --references and --genome are mutually exclusive.
// Each source runs only if the previous ones did not supply fasta (avoids extra datasheet fetches).
//

def resolveReference() {
    if (params.references && params.genome) {
        error("Use either --references or --genome, not both.")
    }

    def meta = explicitReference()

    return meta.fasta
        ? meta
        : params.references
            ? datasheetReference(params.references)
            : params.genome && params.igenomes_ignore
                ? datasheetReference(referencesDatasheetUrl(params.genome))
                : igenomesReference()
}

def explicitReference() {
    def meta = [:]
    if (params.fasta) {
        meta.fasta = params.fasta
    }
    if (params.fasta_fai) {
        meta.fasta_fai = params.fasta_fai
    }
    return meta
}

def datasheetReference(path) {
    def rows = samplesheetToList(path, "${projectDir}/assets/schema_references.json")
    def meta = referenceMeta(selectReferenceRow(rows))
    return meta.findAll { _key, value -> value != null && value != '' }
}

def igenomesReference() {
    def meta = [:]
    def fasta = getGenomeAttribute('fasta')
    def fasta_fai = getGenomeAttribute('fasta_fai')
    if (fasta) {
        meta.fasta = fasta
    }
    if (fasta_fai) {
        meta.fasta_fai = fasta_fai
    }
    return meta
}

def referencesDatasheetUrl(genomeKey) {
    def base = (params.references_base_path ?: '').toString().replaceAll(/\/+$/, '')
    if (!base) {
        error("--references_base_path is empty; cannot load datasheet for --genome '${genomeKey}'")
    }
    def key = genomeKey.toString().replace('.', '/')
    return "${base}/${key}.yml"
}

def selectReferenceRow(rows) {
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

//
// Get attribute from genome config file e.g. fasta
//

def getGenomeAttribute(attribute) {
    if (params.genomes && params.genome && params.genomes.containsKey(params.genome)) {
        if (params.genomes[params.genome].containsKey(attribute)) {
            return params.genomes[params.genome][attribute]
        }
    }
    return null
}
