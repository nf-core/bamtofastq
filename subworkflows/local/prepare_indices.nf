//
// Prepare indices
//

// Initialize channels based on params or indices that were just built
// For all modules here:
// A when clause condition is defined in the conf/modules.config to determine if the module should be run

include { SAMTOOLS_INDEX } from '../../modules/nf-core/samtools/index/main'
include { SAMTOOLS_FAIDX } from '../../modules/nf-core/samtools/faidx/main'


workflow PREPARE_INDICES {
    take:
    input // channel: [meta, alignment (BAM or CRAM), []]
    fasta // optional: reference file if CRAM format and reference not in header

    main:
    ch_out = channel.empty()

    // Determine if INDEX provided
    input
        .branch { files ->
            is_indexed: files[0].index == true
            to_index: files[0].index == false
        }
        .set { samtools_input }

    // Remove empty INDEX [] from channel
    input_to_index = samtools_input.to_index.map { it -> [it[0], it[1]] }

    // INDEX BAM/CRAM only if not provided
    SAMTOOLS_INDEX(input_to_index)
    ch_index_files = channel.empty().mix(SAMTOOLS_INDEX.out.index)

    // Combine channels
    ch_new = input_to_index.join(ch_index_files)
    ch_out = samtools_input.is_indexed.mix(ch_new)


    // INDEX FASTA
    fasta_fai = channel.empty()
    if (params.fasta && !params.fasta_fai) {
        SAMTOOLS_FAIDX(fasta.map { it -> [[id: it[0].baseName], it, []] }, [])
        fasta_fai = SAMTOOLS_FAIDX.out.fai.map { _meta, fai -> [fai] }
    }

    emit:
    ch_input_indexed = ch_out
    fasta_fai        = fasta_fai
}
