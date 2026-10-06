//
// Prepare reference: build FASTA index with samtools faidx when missing
//
// Pattern follows nf-core/sarek PREPARE_GENOME: take plain param values,
// branch in the workflow on whether an index was provided, emit collected
// channels. BAM/CRAM indexing stays in BAMTOFASTQ (SAMTOOLS_INDEX only).
//

include { SAMTOOLS_FAIDX } from '../../../modules/nf-core/samtools/faidx'

workflow PREPARE_REFERENCE {
    take:
    fasta_in // params.fasta: path to genome FASTA or null
    fasta_fai_in // params.fasta_fai: path to prebuilt .fai or null

    main:
    fasta = fasta_in
        ? channel.fromPath(fasta_in).map { fasta_file -> [[id: fasta_file.baseName], fasta_file] }.collect()
        : channel.empty()

    if (fasta_in && fasta_fai_in) {
        fai = channel.fromPath(fasta_fai_in).map { fai_file -> [[id: fai_file.baseName], fai_file] }.collect()
        fasta_fai = fasta
            .combine(fai)
            .map { meta_fasta, fasta_file, _meta_fai, fai_file -> [meta_fasta, fasta_file, fai_file] }
            .collect()
    }
    else if (fasta_in && !fasta_fai_in) {
        SAMTOOLS_FAIDX(fasta.map { meta, fasta_file -> [meta, fasta_file, []] }, false)
        fasta_fai = fasta
            .combine(SAMTOOLS_FAIDX.out.fai.map { meta, fai_file -> [meta, fai_file] })
            .map { meta_fasta, fasta_file, _meta_fai, fai_file -> [meta_fasta, fasta_file, fai_file] }
            .collect()
    }
    else {
        fasta_fai = channel.empty()
    }

    emit:
    fasta // channel: [meta, fasta] collected, or empty
    fasta_fai // channel: [meta, fasta, fai] collected, or empty
}
