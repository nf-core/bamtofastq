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

include { getGenomeAttributeStatic } from 'plugin/nf-core-utils'
include { referenceMeta            } from 'plugin/nf-core-utils'
include { referencesDatasheetUrl   } from 'plugin/nf-core-utils'
include { selectReferenceRow       } from 'plugin/nf-core-utils'
include { samplesheetToList        } from 'plugin/nf-schema'


include { BAMTOFASTQ               } from './workflows/bamtofastq'
include { SAMTOOLS_FAIDX           } from './modules/nf-core/samtools/faidx'
include { PIPELINE_INITIALISATION  } from './subworkflows/local/utils_nfcore_bamtofastq_pipeline'
include { PIPELINE_COMPLETION      } from './subworkflows/local/utils_nfcore_bamtofastq_pipeline'

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

    // REFERENCES
    params.fasta = getReferenceAttribute('fasta')
    params.fasta_fai = getReferenceAttribute('fasta_fai')

    // [meta, fasta, fai] for the run; empty when no reference
    if (!params.fasta) {
        ch_references = channel.empty()
    }
    else if (params.fasta_fai) {
        ch_references = channel.fromPath(params.fasta)
            .collect()
            .combine(channel.fromPath(params.fasta_fai))
            .map { fasta, fasta_fai -> [[id: fasta.baseName], fasta, fasta_fai] }
            .collect()
    }
    else {
        SAMTOOLS_FAIDX(channel.fromPath(params.fasta).map { fasta -> [[id: fasta.baseName], fasta, []] }, false)
        ch_references = channel.fromPath(params.fasta)
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

def getReferenceAttribute(name: String) {
    def genome = params.genome in [null, 'null'] ? null : params.genome
    if (params.references && genome) {
        error("Use either --references or --genome, not both.")
    }
    def sheet = [:]
    if (params.references || genome && params.igenomes_ignore) {
        sheet = loadDatasheetFile(params.references ?: referencesDatasheetUrl(genome, params.references_datasheets_path))
    }
    return sheet[name] ?: getGenomeAttributeStatic(name, params.genomes, genome)
}

def loadDatasheetFile(path: String) {
    return referenceMeta(selectReferenceRow(samplesheetToList(path, "${projectDir}/assets/schema_references.json")))
}
