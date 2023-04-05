process CHECK_IF_PAIRED_END {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::samtools=1.16.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.16.1--h6899075_1' :
        'quay.io/biocontainers/samtools:1.16.1--h6899075_1' }"

    input:
    tuple val(meta), path(input), path(index)
    path fasta

    output:
    tuple val(meta), path("*single.txt"),   emit: single_end, optional: true
    tuple val(meta), path("*paired.txt"),   emit: paired_end, optional: true
    path  "versions.yml",                   emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def reference = meta.filetype == "cram" ? "--reference ${fasta}" : ""
    """
    if [ \$({ samtools view -H $reference $input -@$task.cpus ; samtools view $reference $input -@$task.cpus | head -n1000; } | samtools view $reference $reference -c -f 1 -@$task.cpus | awk '{print \$1/1000}') = "1" ]; then
        echo 1 > ${prefix}.paired.txt
    else
        echo 0 > ${prefix}.single.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}
