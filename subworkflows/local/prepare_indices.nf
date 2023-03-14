//
// Prepare indices
//

// Initialize channels based on params or indices that were just built
// For all modules here:
// A when clause condition is defined in the conf/modules.config to determine if the module should be run

include { SAMTOOLS_INDEX               } from '../../modules/nf-core/samtools/index/main'
include { SAMTOOLS_FAIDX               } from '../../modules/nf-core/samtools/faidx/main'


workflow PREPARE_INDICES {
    take:
    index_provided // boolean determined automatically
    //cram_input     // boolean determined automatically
    input          // channel: [meta, alignment (BAM or CRAM), []]
    fasta          // optional: reference file if CRAM format and reference not in header

    main:

    ch_versions = Channel.empty()

    // INDEX BAM/CRAM if not provided
    ch_input = input.map{ it -> [it[0], it[1]] }
    ch_out = Channel.empty()
    if (!index_provided){
        SAMTOOLS_INDEX((input.map{ it -> [it[0], it[1]] }))
        ch_versions     = ch_versions.mix(SAMTOOLS_INDEX.out.versions)
        ch_index_files  = Channel.empty().mix(SAMTOOLS_INDEX.out.bai, SAMTOOLS_INDEX.out.crai)       
        ch_out          = ch_input.join(ch_index_files)               
        
    }

    // INDEX FASTA
    // fasta_fai = []
    // if(params.fasta && !params.fasta_fai){
    //     SAMTOOLS_FAIDX(fasta.map{ it -> [[id:it[0].baseName], it] })
    //     ch_versions = ch_versions.mix(SAMTOOLS_FAIDX.out.versions)
    //     fasta_fai   = SAMTOOLS_FAIDX.out.fai.map{ meta, fai -> [fai] }

    // }


    // Gather versions of all tools used       
    emit:   
    ch_input    = ch_out
    //fasta_fai   = fasta_fai
    versions    = ch_versions
}
