//
// Pre-conversion QC
//

include { SAMTOOLS_FLAGSTAT               } from '../../modules/nf-core/samtools/flagstat/main'
include { SAMTOOLS_IDXSTATS               } from '../../modules/nf-core/samtools/idxstats/main'
include { SAMTOOLS_STATS                  } from '../../modules/nf-core/samtools/stats/main'
include { FASTQC as FASTQC_PRE_CONVERSION } from '../../modules/nf-core/fastqc/main'

workflow PRE_CONVERSION_QC {
    take:
    input // channel: [meta, alignment (BAM or CRAM), index (optional)]
    fasta_fai

    main:
    // SAMTOOLS IDXSTATS
    SAMTOOLS_IDXSTATS(input)

    // SAMTOOLS FLAGSTAT
    SAMTOOLS_FLAGSTAT(input)

    // SAMTOOLS STATS
    SAMTOOLS_STATS(input, fasta_fai)

    // FASTQC ONLY ON BAM
    input
        .branch { files ->
            bam: files[0].filetype == 'bam'
            cram: files[0].filetype == 'cram'
        }
        .set { fastqc_input }

    FASTQC_PRE_CONVERSION(
        fastqc_input.bam.map { it ->
            [
                it[0],
                it[1],
            ]
        }
    )

    emit:
    flagstat = SAMTOOLS_FLAGSTAT.out.flagstat
    idxstats = SAMTOOLS_IDXSTATS.out.idxstats
    stats    = SAMTOOLS_STATS.out.stats
    zip      = FASTQC_PRE_CONVERSION.out.zip
    html     = FASTQC_PRE_CONVERSION.out.html
}