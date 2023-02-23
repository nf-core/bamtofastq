/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowBamtofastq.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config, params.fasta ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = extract_csv(file(params.input, checkIfExists: true)) } else { exit 1, 'Input samplesheet not specified!' }


// Initialize file channels based on params
fasta              = params.fasta              ? Channel.fromPath(params.fasta).collect()                    : Channel.value([])
//TODO: compute fai if not provided
fasta_fai          = params.fasta_fai          ? Channel.fromPath(params.fasta_fai).collect()                : Channel.value([])

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                               } from '../modules/nf-core/fastqc/main'
include { SAMTOOLS_VIEW as SAMTOOLS_CHR        } from '../modules/nf-core/samtools/view/main'
include { SAMTOOLS_INDEX as SAMTOOLS_CHR_INDEX } from '../modules/nf-core/samtools/index/main'

include { MULTIQC                       } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS   } from '../modules/nf-core/custom/dumpsoftwareversions/main'

//
// SUBWORKFLOWS: Installed directly from subworkflows/local
//

include { ALIGNMENT_TO_FASTQ          } from '../subworkflows/local/alignment_to_fastq'
include { PRE_QC                      } from '../subworkflows/local/pre_qc'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow BAMTOFASTQ {

    ch_versions = Channel.empty()

    // Pre conversion QC

    PRE_QC(
        ch_input,
        fasta
    )

    ch_versions = ch_versions.mix(PRE_QC.out.versions)

    // Check for single or paired end

    // Extract only reads mapping to a chromosome
    if (params.chr) {

        SAMTOOLS_CHR(ch_input, fasta, [])

        samtools_chr_out = Channel.empty().mix(SAMTOOLS_CHR.out.bam,
                                                SAMTOOLS_CHR.out.cram)
        SAMTOOLS_CHR_INDEX(samtools_chr_out)
        ch_input = samtools_chr_out.join(Channel.empty().mix(SAMTOOLS_CHR_INDEX.out.bai,
                                                            SAMTOOLS_CHR_INDEX.out.crai))
        //ch_input.dump(tag:"chr input")

        ch_versions = ch_versions.mix(SAMTOOLS_CHR.out.versions)
        ch_versions = ch_versions.mix(SAMTOOLS_CHR_INDEX.out.versions)

    }
    //
    // SUBWORKFLOW: Alignment to FastQ
    //
    //ch_input.dump(tag:"aln input")
    ALIGNMENT_TO_FASTQ (
        ch_input,
        fasta,
        fasta_fai
    )

    ch_versions = ch_versions.mix(ALIGNMENT_TO_FASTQ.out.versions)


    // Post conversion QC

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowBamtofastq.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowBamtofastq.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    //ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))


    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.collect().ifEmpty([]),
        ch_multiqc_custom_config.collect().ifEmpty([]),
        ch_multiqc_logo.collect().ifEmpty([])
    )
    multiqc_report = MULTIQC.out.report.toList()
    ch_versions    = ch_versions.mix(MULTIQC.out.versions)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.adaptivecard(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// Function to extract information (meta data + file(s)) from csv file(s)
def extract_csv(csv_file) {

    // check that the sample sheet is not 1 line or less, because it'll skip all subsequent checks if so.
    file(csv_file).withReader('UTF-8') { reader ->
        def line, numberOfLinesInSampleSheet = 0;
        while ((line = reader.readLine()) != null) {numberOfLinesInSampleSheet++}
        if (numberOfLinesInSampleSheet < 2) {
            log.error "Samplesheet had less than two lines. The sample sheet must be a csv file with a header, so at least two lines."
            System.exit(1)
        }
    }
    Channel.from(csv_file).splitCsv(header: true)
        .map{ row ->
            if ( !row.sample_id ) {  // This also handles the case where the lane is left as an empty string
                log.error('The sample sheet should specify a sample_id for each row.\n' + row.toString())
                System.exit(1)
            }
            if ( !row.mapped ) {  // This also handles the case where the lane is left as an empty string
                log.error('The sample sheet should specify a mapped file for each row.\n' + row.toString())
                System.exit(1)
            }
            if (!row.file_type) {  // This also handles the case where the lane is left as an empty string
                log.error('The sample sheet should specify a file_type for each row, valid values are bam/cram.\n' + row.toString())
                System.exit(1)
            }
            if (!(row.file_type == "bam" || row.file_type == "cram")) {
                log.error('The file_type for the row below is neither "bam" nor "cram". Please correct this.\n' + row.toString() )
                System.exit(1)
            }
            if (row.file_type != file(row.mapped).getExtension().toString()) {
                log.error('The file extension does not fit the specified file_type.\n' + row.toString() )
                System.exit(1)
            }


            // init meta map
            def meta = [:]

            meta.id       = "${row.sample_id}".toString()
            def mapped    = file(row.mapped, checkIfExists: true)
            def index     = row.index ? file(row.index, checkIfExists: true) : []
            meta.filetype = "${row.file_type}".toString()

            return [meta, mapped, index]

            }

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
