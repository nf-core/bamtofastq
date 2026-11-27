// Helper functions for pipeline tests

class UTILS {

    public static def getAssertions = { Map args ->
        // Mandatory, as we always need an outdir
        def outdir = args.outdir

        // Get scenario and extract all properties dynamically
        def scenario = args.scenario ?: [:]

        // Pass down workflow for std capture
        def workflow = args.workflow

        // These strings are not stable and should be ignored
        def snapshot_ignore_list = [
            "Downloading plugin",
            "Pulling Singularity image",
            "Staging foreign file",
            "Unrecognized config option 'manifest.diagram'",
        ]

        // stable_name: All files + folders in ${outdir}/ with a stable name
        def stable_name = getAllFilesFromPath(outdir, relative: true, includeDir: true, ignore: ['pipeline_info/*.{html,json,txt}'])
        // stable_content: All files in ${outdir}/ with stable content
        def stable_content = getAllFilesFromPath(outdir, ignoreFile: 'tests/.nftignore')
        // bam_files: All bam files
        def bam_files = getAllFilesFromPath(outdir, include: ['**/*.bam'])

        def assertion = []
        // getAllFilesFromPath returns relative paths (strings), so this resolves to an absolute path
        def absolutePath = { file -> file.toString().startsWith('/') ? file.toString() : "${outdir}/${file}" }

        if (!scenario.failure) {
            assertion.add(workflow.trace.succeeded().size())
            assertion.add(removeFromYamlMap("${outdir}/pipeline_info/nf_core_bamtofastq_software_mqc_versions.yml", "Workflow") ?: 'No versions')
            assertion.add(stable_name)
            assertion.add(stable_content.isEmpty() ? 'No stable content' : stable_content.collect { file -> path(absolutePath(file)) })
            assertion.add(bam_files.isEmpty() ? 'No BAM files' : bam_files.collect { file -> file.tokenize('/').last() + ":md5," + bam(absolutePath(file)).readsMD5 })
        }

        // We always capture stdout and stderr for any WARN message
        def filter_args = [ignore: snapshot_ignore_list + (scenario.snapshot_ignore ?: [])]

        assertion.add(filterNextflowOutput(workflow.stderr + workflow.stdout, filter_args + [include: ["WARN"]]) ?: "No warnings")

        // With a snapshot option in the scenario, also capture stderr, stdout or both, optionally only lines including a string
        if (scenario.snapshot) {
            def workflow_std = scenario.snapshot.split(',')
                .findAll { std -> std in ['stderr', 'stdout'] }
                .collect { std -> workflow."$std" }
                .flatten()

            if (scenario.snapshot_include) {
                filter_args.include = [scenario.snapshot_include]
            }

            assertion.add(filterNextflowOutput(workflow_std, filter_args) ?: "No content")
        }

        return assertion
    }

    public static def getTest = { scenario ->
        // This function returns a closure that will be used to run the test and the assertion
        return {
            tag "pipeline"
            tag "pipeline_bamtofastq"
            tag "cpu"

            // Add automatic failure tag if it's a scenario supposed to fail
            if (scenario.failure) {
                tag "failure"
            }

            when {
                params {
                    // Mandatory, as we always need an outdir
                    outdir = "${outputDir}"
                    // Apply scenario-specific params
                    scenario.params.each { key, value ->
                        delegate."$key" = value
                    }
                }
            }

            then {
                // Assert failure/success, and fails early so we don't pollute console with massive diffs
                if (scenario.failure) {
                    assert workflow.failed
                } else {
                    assert workflow.success
                }
                assertAll(
                    { assert snapshot(
                        // All assertions based on the scenario
                        *UTILS.getAssertions(
                            outdir: params.outdir,
                            scenario: scenario,
                            workflow: workflow
                        )
                    ).match() }
                )
            }
        }
    }
}
