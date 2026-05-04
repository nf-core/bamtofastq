process CHECK_IF_PAIRED_END {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8c/8c5d2818c8b9f58e1fba77ce219fdaf32087ae53e857c4a496402978af26e78c/data'
        : 'community.wave.seqera.io/library/htslib_samtools:1.23.1--5b6bb4ede7e612e5'}"

    input:
    tuple val(meta), path(input), path(index)
    tuple val(meta2), path(fasta), path(fai)

    output:
    tuple val(meta), path("*single.txt"), emit: single_end, optional: true
    tuple val(meta), path("*paired.txt"), emit: paired_end, optional: true
    tuple val("${task.process}"), val('samtools'), eval("samtools version | sed '1!d;s/.* //'"), topic: versions, emit: versions_samtools

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def reference = meta.filetype == "cram" ? "--reference ${fasta}" : ""
    """
    if [ "\$( samtools view ${reference} ${input} -@${task.cpus} | head -n1000 | wc -l)" -lt "1000" ]; then
        LINES_TO_CHK=\$( samtools view ${reference} ${input} -@${task.cpus} | wc -l)
    else
        LINES_TO_CHK=1000
    fi

    if [ \$({ samtools view -H ${reference} ${input} -@${task.cpus} ; samtools view ${reference} ${input} -@${task.cpus} | head -n\$LINES_TO_CHK; } | samtools view ${reference} -c -f 1 -@${task.cpus} | awk -v lines=\$LINES_TO_CHK '{print \$1/lines}') = "1" ]; then
        echo 1 > ${prefix}.paired.txt
    else
        echo 1 > ${prefix}.single.txt
    fi
    """
}
