//
// BAM/CRAM to FASTQ conversion, paired end only
//

include { SAMTOOLS_VIEW  as SAMTOOLS_VIEW_MAP_MAP      } from '../../modules/nf-core/samtools/view/main'
include { SAMTOOLS_VIEW  as SAMTOOLS_VIEW_UNMAP_UNMAP  } from '../../modules/nf-core/samtools/view/main'
include { SAMTOOLS_VIEW  as SAMTOOLS_VIEW_UNMAP_MAP    } from '../../modules/nf-core/samtools/view/main'
include { SAMTOOLS_VIEW  as SAMTOOLS_VIEW_MAP_UNMAP    } from '../../modules/nf-core/samtools/view/main'
include { SAMTOOLS_MERGE as SAMTOOLS_MERGE_UNMAP       } from '../../modules/nf-core/samtools/merge/main'
include { SAMTOOLS_COLLATEFASTQ as COLLATE_FASTQ_UNMAP } from '../../modules/nf-core/samtools/collatefastq/main'
include { SAMTOOLS_COLLATEFASTQ as COLLATE_FASTQ_MAP   } from '../../modules/nf-core/samtools/collatefastq/main'
include { CAT_FASTQ                                    } from '../../modules/nf-core/cat/fastq/main'

workflow ALIGNMENT_TO_FASTQ {
    take:
    input // channel: [meta, alignment (BAM or CRAM), index (optional)]
    fasta // optional: reference file if CRAM format and reference not in header
    fasta_fai

    main:

    ch_versions = Channel.empty()
    // Index File if not PROVIDED -> this also requires updates to samtools view possibly URGH

    // MAP - MAP
    SAMTOOLS_VIEW_MAP_MAP(input, fasta.map{ it -> [[:], it] }, [], [])

    // UNMAP - UNMAP
    SAMTOOLS_VIEW_UNMAP_UNMAP(input, fasta.map{ it -> [[:], it] }, [], [])

    // UNMAP - MAP
    SAMTOOLS_VIEW_UNMAP_MAP(input, fasta.map{ it -> [[:], it] }, [], [])

    // MAP - UNMAP
    SAMTOOLS_VIEW_MAP_UNMAP(input, fasta.map{ it -> [[:], it] }, [], [])

    // Channel for merging UNMAPPED BAM
    all_unmapped_bam = SAMTOOLS_VIEW_UNMAP_UNMAP.out.bam
        .join(SAMTOOLS_VIEW_UNMAP_MAP.out.bam, remainder: true)
        .join(SAMTOOLS_VIEW_MAP_UNMAP.out.bam, remainder: true)
        .map{ meta, unmap_unmap, unmap_map, map_unmap ->
            [meta, [unmap_unmap, unmap_map, map_unmap]]
        }

    // Channel for merging UNMAPPED CRAM
    all_unmapped_cram = SAMTOOLS_VIEW_UNMAP_UNMAP.out.cram
        .join(SAMTOOLS_VIEW_UNMAP_MAP.out.cram, remainder: true)
        .join(SAMTOOLS_VIEW_MAP_UNMAP.out.cram, remainder: true)
        .map{ meta, unmap_unmap, unmap_map, map_unmap ->
            [meta, [unmap_unmap, unmap_map, map_unmap]]
        }

    // Combine UNMAPPED channels
    ch_unmapped_bam_cram = Channel.empty().mix(all_unmapped_bam,all_unmapped_cram)

    // MERGE UNMAP
    SAMTOOLS_MERGE_UNMAP(ch_unmapped_bam_cram, fasta.map{ it -> [[:], it] }, fasta_fai.map{ it -> [[:], it] })

    def interleave = false

    // SortExtractUnmapped: Collate & convert unmapped
    COLLATE_FASTQ_UNMAP(SAMTOOLS_MERGE_UNMAP.out.cram.mix(SAMTOOLS_MERGE_UNMAP.out.bam), fasta.map{ it ->
                def new_id = ""
                if(it) {
                    new_id = it[0].baseName
                }
                [[id:new_id], it] },
                interleave)

    // /SortExtractMapped: Collate & convert mapped
    COLLATE_FASTQ_MAP(SAMTOOLS_VIEW_MAP_MAP.out.cram.mix(SAMTOOLS_VIEW_MAP_MAP.out.bam), fasta.map{ it ->
                def new_id = ""
                if(it) {
                    new_id = it[0].baseName
                }
                [[id:new_id], it] },
                interleave)

    // Channel for joining mapped & unmapped fastq
    reads_to_concat = COLLATE_FASTQ_MAP.out.fastq
        .join(COLLATE_FASTQ_UNMAP.out.fastq)
        .map{ meta, mapped_reads, unmapped_reads ->
            [meta, [
            mapped_reads[0],
            mapped_reads[1],
            unmapped_reads[0],
            unmapped_reads[1]]
            ]
        }

    // Concatenate Mapped_R1 with Unmapped_R1 and Mapped_R2 with Unmapped_R2
    CAT_FASTQ(reads_to_concat)

    // Gather versions of all tools used
    ch_versions = ch_versions.mix(CAT_FASTQ.out.versions)
    ch_versions = ch_versions.mix(COLLATE_FASTQ_MAP.out.versions)
    ch_versions = ch_versions.mix(COLLATE_FASTQ_UNMAP.out.versions)
    ch_versions = ch_versions.mix(SAMTOOLS_MERGE_UNMAP.out.versions)
    ch_versions = ch_versions.mix(SAMTOOLS_VIEW_MAP_MAP.out.versions)
    ch_versions = ch_versions.mix(SAMTOOLS_VIEW_MAP_UNMAP.out.versions)
    ch_versions = ch_versions.mix(SAMTOOLS_VIEW_UNMAP_MAP.out.versions)
    ch_versions = ch_versions.mix(SAMTOOLS_VIEW_UNMAP_UNMAP.out.versions)

    emit:
    reads            = CAT_FASTQ.out.reads
    versions         = ch_versions
}
