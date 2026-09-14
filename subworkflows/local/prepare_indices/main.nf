//
// Prepare indices
//

// Initialize channels based on params or indices that were just built
// For all modules here:
// A when clause condition is defined in the conf/modules.config to determine if the module should be run

include { SAMTOOLS_INDEX } from '../../../modules/nf-core/samtools/index'
include { SAMTOOLS_FAIDX } from '../../../modules/nf-core/samtools/faidx'


workflow PREPARE_INDICES {
    take:
    input // channel: [meta, alignment (BAM or CRAM), []]
    fasta_fai // optional: reference file if CRAM format and reference not in header

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

    // Combine channels
    ch_new = input_to_index.join(SAMTOOLS_INDEX.out.index)
    ch_out = samtools_input.is_indexed.mix(ch_new)

    // INDEX FASTA
    fasta_fai
        .branch { meta, _fasta_file, _fai_file ->
            is_fasta_indexed: meta.index == true
            to_index:         meta.index == false
        }
        .set { fasta_branch }

    SAMTOOLS_FAIDX(fasta_branch.to_index.map { m, f, _i -> [m, f, []] }, [[],[]])

    // Reconstruct: take the original [meta, fasta] and combine with the NEW fai
    // This ignores the ID entirely and just pairs the file with the index
    fasta_newly_indexed = fasta_branch.to_index
        .map { meta, fasta, _old_fai -> [meta, fasta] }
        .combine(SAMTOOLS_FAIDX.out.fai.map { _meta, fai -> fai })
        .map { meta, fasta, new_fai -> [meta, fasta, new_fai] }

    ch_fasta_fai = fasta_branch.is_fasta_indexed
        .mix(fasta_newly_indexed)
        .first()

    emit:
    ch_input_indexed = ch_out
    ch_fasta_fai     = ch_fasta_fai
}
