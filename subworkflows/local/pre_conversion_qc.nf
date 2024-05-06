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
    fasta // optional: reference file if CRAM format and reference not in header

    main:

    ch_versions = Channel.empty()

    // SAMTOOLS IDXSTATS
    SAMTOOLS_IDXSTATS(input)

    // SAMTOOLS FLAGSTAT
    SAMTOOLS_FLAGSTAT(input)

    // SAMTOOLS STATS
    SAMTOOLS_STATS(input, fasta.map{ it -> [[:], it] })

    // FASTQC ONLY ON BAM
    input.branch{
        bam:  it[0].filetype == 'bam'
        cram: it[0].filetype == 'cram'
    }.set{fastqc_input}

    FASTQC_PRE_CONVERSION(fastqc_input.bam
        .map{ it ->
            [it[0], // meta
            it[1]]  // bam
        })

    // Gather versions of all tools used
    ch_versions = ch_versions.mix(SAMTOOLS_IDXSTATS.out.versions)
    ch_versions = ch_versions.mix(SAMTOOLS_FLAGSTAT.out.versions)
    ch_versions = ch_versions.mix(SAMTOOLS_STATS.out.versions)
    ch_versions = ch_versions.mix(FASTQC_PRE_CONVERSION.out.versions)

    emit:
    flagstat    = SAMTOOLS_FLAGSTAT.out.flagstat
    idxstats    = SAMTOOLS_IDXSTATS.out.idxstats
    stats       = SAMTOOLS_STATS.out.stats
    zip         = FASTQC_PRE_CONVERSION.out.zip
    html        = FASTQC_PRE_CONVERSION.out.html
    versions    = ch_versions
}
