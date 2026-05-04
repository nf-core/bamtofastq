/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { methodsDescriptionText                                    } from '../subworkflows/local/utils_nfcore_bamtofastq_pipeline'
include { paramsSummaryMap                                          } from 'plugin/nf-schema'
include { paramsSummaryMultiqc                                      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML                                    } from '../subworkflows/nf-core/utils_nfcore_pipeline'

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
include { FASTQUTILS_INFO                                           } from '../modules/nf-core/fastqutils/info/main'
include { SAMTOOLS_VIEW as SAMTOOLS_CHR                             } from '../modules/nf-core/samtools/view/main'
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
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    outdir

    main:

    // Initialize file channels based on params
    fasta = params.fasta ? channel.fromPath(params.fasta).collect() : channel.empty()

    // Initialize value channels based on params
    // chr = params.chr ?: channel.empty() // declared but not used
    ch_multiqc_files = channel.empty()

    // SUBWORKFLOW: Prepare indices bai/crai/fai if not provided
    PREPARE_INDICES(
        ch_samplesheet,
        fasta,
    )
    fai = params.fasta ? params.fasta_fai ? channel.fromPath(params.fasta_fai).collect() : PREPARE_INDICES.out.fasta_fai : channel.empty()
    ch_fasta_fai = params.fasta ? fasta.combine(fai).map { fasta_file, fai_file -> [ [id: fasta_file.baseName], fasta_file, fai_file ] } : channel.empty()

    // SUBWORKFLOW: Pre conversion QC and stats
    ch_input = PREPARE_INDICES.out.ch_input_indexed
    PRE_CONVERSION_QC(
        ch_input,
        ch_fasta_fai,
    )

    // MODULE: Check if SINGLE or PAIRED-END
    CHECK_IF_PAIRED_END(ch_input, ch_fasta_fai)

    ch_paired_end = ch_input.join(CHECK_IF_PAIRED_END.out.paired_end)
    ch_single_end = ch_input.join(CHECK_IF_PAIRED_END.out.single_end)

    // Combine channels into new input channel for conversion + add info about single/paired to meta map
    ch_input_new = ch_single_end
        .map { meta, bam, bai, _txt ->
            [
                [
                    id: meta.id,
                    filetype: meta.filetype,
                    single_end: true,
                ],
                bam,
                bai,
            ]
        }
        .mix(
            ch_paired_end.map { meta, bam, bai, _txt ->
                [
                    [
                        id: meta.id,
                        filetype: meta.filetype,
                        single_end: false,
                    ],
                    bam,
                    bai,
                ]
            }
        )


    // Extract only reads mapping to a chromosome
    if (params.chr) {

        SAMTOOLS_CHR(ch_input_new, fasta.map { it -> [[:], it, []] }, [[:], []], [[:], []], [])

        samtools_chr_out = channel.empty()
            .mix(
                SAMTOOLS_CHR.out.bam,
                SAMTOOLS_CHR.out.cram,
            )
        SAMTOOLS_CHR_INDEX(samtools_chr_out)
        ch_input_chr = samtools_chr_out.join(
            channel.empty().mix(
                SAMTOOLS_CHR_INDEX.out.bai,
                SAMTOOLS_CHR_INDEX.out.crai,
            )
        )

        // Add chr names to id
        ch_input_new = ch_input_chr.map { it ->
            def new_id = it[1].baseName
            [
                [
                    id: new_id,
                    filetype: it[0].filetype,
                    single_end: it[0].single_end,
                ],
                it[1],
                it[2],
            ]
        }
    }

    // MODULE: SINGLE-END Alignment to FastQ (SortExtractSingleEnd)
    def interleave = false

    ch_input_new
        .branch { files ->
            ch_single: files[0].single_end == true
            ch_paired: files[0].single_end == false
        }
        .set { conversion_input }

    // Module needs info about single-endedness
    SAMTOOLS_COLLATEFASTQ_SINGLE_END(
        conversion_input.ch_single.map { it -> [it[0], it[1]] },
        ch_fasta_fai,
        interleave,
    )

    //
    // SUBWORKFLOW: PAIRED-END Alignment to FastQ
    //
    ALIGNMENT_TO_FASTQ(
        conversion_input.ch_paired,
        ch_fasta_fai,
    )

    // NOTE: TEMPORARILY DISABLED BY ASP FOR DEBUGGING!!!!
    // ch_multiqc_files = ch_multiqc_files.mix(ALIGNMENT_TO_FASTQ.out.zip.collect{it[1]}) // there is not zip in the output of the subworkflow?


    // MODULE: FastQC - Post conversion QC
    // famosab: swapped the output of SAMTOOLS_COLLATEFASTQ_SINGLE_END from fastq_singleton to fastq_other because otherwise the fatsq files had empty reads
    // coming from the samtools docs its not clear which file contains the expected reads
    ch_reads_post_qc = channel.empty().mix(SAMTOOLS_COLLATEFASTQ_SINGLE_END.out.fastq_other, ALIGNMENT_TO_FASTQ.out.reads)

    FASTQC_POST_CONVERSION(ch_reads_post_qc)

    // MODULE: fastq_utils - Post conversion checks for broken fastq files
    FASTQUTILS_INFO(ch_reads_post_qc)

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [process[process.lastIndexOf(':') + 1..-1], "  ${tool}: ${version}"]
        }
        .groupTuple(by: 0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(topic_versions.versions_file)
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_'  +  'bamtofastq_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    //
    // MODULE: MultiQC
    //
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    def ch_multiqc_custom_methods_description = multiqc_methods_description
        ? file(multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))
    MULTIQC(
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [id: 'bamtofastq'],
                files,
                multiqc_config
                    ? file(multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )
    emit:
    multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList() // channel: /path/to/multiqc_report.html
}
