/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMap       } from 'plugin/nf-validation'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_bamtofastq_pipeline'
include { paramsSummaryMultiqc; softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'

// Initialize file channels based on params
fasta     = params.fasta     ? Channel.fromPath(params.fasta).collect()      : Channel.value([])

// Initialize value channels based on params
chr       = params.chr       ?: Channel.empty()

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { CHECK_IF_PAIRED_END                                       } from '../modules/local/check_paired_end'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC as FASTQC_POST_CONVERSION                          } from '../modules/nf-core/fastqc/main'
include { SAMTOOLS_VIEW as SAMTOOLS_CHR                             } from '../modules/nf-core/samtools/view/main'
include { SAMTOOLS_VIEW as SAMTOOLS_PE                              } from '../modules/nf-core/samtools/view/main'
include { SAMTOOLS_INDEX as SAMTOOLS_CHR_INDEX                      } from '../modules/nf-core/samtools/index/main'
include { SAMTOOLS_COLLATEFASTQ as SAMTOOLS_COLLATEFASTQ_SINGLE_END } from '../modules/nf-core/samtools/collatefastq/main'

include { MULTIQC                                                   } from '../modules/nf-core/multiqc/main'

//
// SUBWORKFLOWS: Installed directly from subworkflows/local
//

include { PREPARE_INDICES                                           } from '../subworkflows/local/prepare_indices'
include { PRE_CONVERSION_QC                                         } from '../subworkflows/local/pre_conversion_qc'
include { ALIGNMENT_TO_FASTQ                                        } from '../subworkflows/local/alignment_to_fastq'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow BAMTOFASTQ {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // SUBWORKFLOW: Prepare indices bai/crai/fai if not provided
    PREPARE_INDICES(
        ch_samplesheet,
        fasta
    )

    ch_versions = ch_versions.mix(PREPARE_INDICES.out.versions)

    // SUBWORKFLOW: Pre conversion QC and stats

    ch_input = PREPARE_INDICES.out.ch_input_indexed
    PRE_CONVERSION_QC(
        ch_input,
        fasta
    )

    ch_versions = ch_versions.mix(PRE_CONVERSION_QC.out.versions)

    // MODULE: Check if SINGLE or PAIRED-END

    CHECK_IF_PAIRED_END(ch_input, fasta)

    ch_paired_end = ch_input.join(CHECK_IF_PAIRED_END.out.paired_end)
    ch_single_end = ch_input.join(CHECK_IF_PAIRED_END.out.single_end)

    // Combine channels into new input channel for conversion + add info about single/paired to meta map
    ch_input_new = ch_single_end.map{ meta, bam, bai, txt ->
            [ [ id : meta.id,
            filetype : meta.filetype,
            single_end : true ],
            bam,
            bai
            ] }
        .mix(ch_paired_end.map{ meta, bam, bai, txt ->
            [ [ id : meta.id,
            filetype : meta.filetype,
            single_end : false ],
            bam,
            bai
            ] })

    ch_versions = ch_versions.mix(CHECK_IF_PAIRED_END.out.versions)


    // Extract only reads mapping to a chromosome
    if (params.chr) {

        SAMTOOLS_CHR(ch_input_new, fasta.map{ it -> [[:], it] }, [])

        samtools_chr_out = Channel.empty().mix( SAMTOOLS_CHR.out.bam,
                                                SAMTOOLS_CHR.out.cram)
        SAMTOOLS_CHR_INDEX(samtools_chr_out)
        ch_input_chr = samtools_chr_out.join(Channel.empty().mix( SAMTOOLS_CHR_INDEX.out.bai,
                                                                SAMTOOLS_CHR_INDEX.out.crai ))

        // Add chr names to id
        ch_input_new = ch_input_chr.map{ it ->
                new_id = it[1].baseName
                [[
                    id : new_id,
                    filetype : it[0].filetype,
                    single_end: it[0].single_end
                ],
                it[1],
                it[2]] }

        ch_versions = ch_versions.mix(SAMTOOLS_CHR.out.versions)
        ch_versions = ch_versions.mix(SAMTOOLS_CHR_INDEX.out.versions)

    }

    // MODULE: SINGLE-END Alignment to FastQ (SortExtractSingleEnd)
    def interleave = false

    ch_input_new.branch{
        ch_single:  it[0].single_end == true
        ch_paired:  it[0].single_end == false
    }.set{conversion_input}

    // Module needs info about single-endedness
    SAMTOOLS_COLLATEFASTQ_SINGLE_END(
        conversion_input.ch_single.map{ it -> [ it[0], it[1] ]}, // meta, bam/cram
        fasta.map{ it ->                                         // meta, fasta
            def new_id = ""
            if(it) {
                new_id = it[0].baseName
            }
            [[id:new_id], it] },
        interleave)

    ch_versions = ch_versions.mix(SAMTOOLS_COLLATEFASTQ_SINGLE_END.out.versions)

    //
    // SUBWORKFLOW: PAIRED-END Alignment to FastQ
    //

    fasta_fai = params.fasta ? params.fasta_fai ? Channel.fromPath(params.fasta_fai).collect() : PREPARE_INDICES.out.fasta_fai : Channel.value([])
    ALIGNMENT_TO_FASTQ (
        conversion_input.ch_paired,
        fasta,
        fasta_fai
    )

    // NOTE: TEMPORARILY DISABLED BY ASP FOR DEBUGGING!!!!
    // ch_multiqc_files = ch_multiqc_files.mix(ALIGNMENT_TO_FASTQ.out.zip.collect{it[1]})
    ch_versions = ch_versions.mix(ALIGNMENT_TO_FASTQ.out.versions)


    // MODULE: FastQC - Post conversion QC
    ch_reads_post_qc = Channel.empty().mix(SAMTOOLS_COLLATEFASTQ_SINGLE_END.out.fastq_singleton, ALIGNMENT_TO_FASTQ.out.reads)

    FASTQC_POST_CONVERSION(ch_reads_post_qc)

    ch_versions = ch_versions.mix(FASTQC_POST_CONVERSION.out.versions)

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'nf_core_pipeline_software_mqc_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config                     = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config              = params.multiqc_config ? Channel.fromPath(params.multiqc_config, checkIfExists: true) : Channel.empty()
    ch_multiqc_logo                       = params.multiqc_logo ? Channel.fromPath(params.multiqc_logo, checkIfExists: true) : Channel.empty()
    summary_params                        = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary                   = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: false))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
