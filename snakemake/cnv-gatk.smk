## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## Collect read counts
## See: https://software.broadinstitute.org/gatk/documentation/article?id=11682
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule collectreadcounts:
    input:
        "results/bqsr/{aliquot_id}.realn.mdup.bqsr.bam"
    output:
        "results/collectreadcounts/{batch}/{aliquot_id}.counts.hdf5"
    params:
        mem = CLUSTER_META["collectreadcounts"]["mem"]
    threads:
        CLUSTER_META["collectreadcounts"]["ppn"]
    log:
        "logs/collectreadcounts/{batch}/{aliquot_id}.log"
    benchmark:
        "benchmarks/collectreadcounts/{batch}/{aliquot_id}.txt"
    message:
        "Collecting read counts\n"
        "Batch: {wildcards.batch}\n"
        "Sample: {wildcards.aliquot_id}"
    shell:
        "gatk --java-options -Xmx{params.mem}g CollectReadCounts \
            -I {input} \
            -L {config[cnv_intervals]} \
            --interval-merging-rule OVERLAPPING_ONLY \
            -O {output} \
            > {log} 2>&1"

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## Create CNV panel of normals
## See: https://software.broadinstitute.org/gatk/documentation/article?id=11682
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule createcnvpon:
    input:
        lambda wildcards: expand("results/collectreadcounts/{batch}/{aliquot_id}.counts.hdf5", batch=wildcards.batch, aliquot_id=BATCH_TO_NORMAL[wildcards.batch]) 
    output:
        "results/createcnvpon/{batch}.pon.hdf5"
    params:
        mem = CLUSTER_META["createcnvpon"]["mem"]
    threads:
        CLUSTER_META["createcnvpon"]["ppn"]
    log:
        "logs/createcnvpon/{batch}.log"
    benchmark:
        "benchmarks/createcnvpon/{batch}.txt"
    message:
        "Creating CNV panel of normals\n"
        "Batch: {wildcards.batch}"
    run:
        vcfs = " ".join(["-I " + s for s in input])
        shell("gatk --java-options -Xmx{params.mem}g CreateReadCountPanelOfNormals \
                {vcfs} \
                --minimum-interval-median-percentile 5.0 \
                -O {output} \
                > {log} 2>&1")

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## Denoise read counts
## See: https://software.broadinstitute.org/gatk/documentation/article?id=11682
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule denoisereadcounts:
    input:
        sample = lambda wildcards: "results/collectreadcounts/{batch}/{aliquot_id}.counts.hdf5".format(batch = CASES_DICT[SAMPLES_DICT[ALIQUOTS_DICT[wildcards.aliquot_id]["sample_id"]]["case_id"]]["project_id"], aliquot_id=wildcards.aliquot_id),
        pon =  lambda wildcards: "results/createcnvpon/{batch}.pon.hdf5".format(batch = CASES_DICT[SAMPLES_DICT[ALIQUOTS_DICT[wildcards.aliquot_id]["sample_id"]]["case_id"]]["project_id"])
    output:
        standardized = "results/denoisereadcounts/{aliquot_id}.standardizedCR.tsv",
        denoised = "results/denoisereadcounts/{aliquot_id}.denoisedCR.tsv"
    params:
        mem = CLUSTER_META["denoisereadcounts"]["mem"]
    threads:
        CLUSTER_META["denoisereadcounts"]["ppn"]
    log:
        "logs/denoisereadcounts/{aliquot_id}.log"
    benchmark:
        "benchmarks/denoisereadcounts/{aliquot_id}.txt"
    message:
        "Denoising and standardizing read counts\n"
        "Aliquot: {wildcards.aliquot_id}"
    shell:
        "gatk --java-options -Xmx{params.mem}g DenoiseReadCounts \
            -I {input.sample} \
            --count-panel-of-normals {input.pon} \
            --interval-merging-rule OVERLAPPING_ONLY \
            --standardized-copy-ratios {output.standardized} \
            --denoised-copy-ratios {output.denoised} \
            > {log} 2>&1"

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## Plot denoised and standardized copy ratios
## See: https://software.broadinstitute.org/gatk/documentation/article?id=11682
## NB need to optimize minimum contig length parameter for b37
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule plotcr:
    input:
        standardized = "results/denoisereadcounts/{aliquot_id}.standardizedCR.tsv",
        denoised = "results/denoisereadcounts/{aliquot_id}.denoisedCR.tsv"
    output:
        "results/plotcr/{aliquot_id}/{aliquot_id}.denoised.png",
        "results/plotcr/{aliquot_id}/{aliquot_id}.denoisedLimit4.png",
        "results/plotcr/{aliquot_id}/{aliquot_id}.standardizedMAD.txt",
        "results/plotcr/{aliquot_id}/{aliquot_id}.denoisedMAD.txt",
        "results/plotcr/{aliquot_id}/{aliquot_id}.deltaMAD.txt",
        "results/plotcr/{aliquot_id}/{aliquot_id}.scaledDeltaMAD.txt"
    params:
        mem = CLUSTER_META["plotcr"]["mem"],
        outputdir = "results/plotcr/{aliquot_id}",
        outputprefix = "{aliquot_id}"
    threads:
        CLUSTER_META["plotcr"]["ppn"]
    log:
        "logs/plotcr/{aliquot_id}.log"
    benchmark:
        "benchmarks/plotcr/{aliquot_id}.txt"
    message:
        "Plot denoised and standardized read counts\n"
        "Aliquot: {wildcards.aliquot_id}"
    shell:
        "gatk --java-options -Xmx{params.mem}g PlotDenoisedCopyRatios \
            --standardized-copy-ratios {input.standardized} \
            --denoised-copy-ratios {input.denoised} \
            --sequence-dictionary {config[reference_dict]} \
            --minimum-contig-length 46709983 \
            --standardized-copy-ratios {output.standardized} \
            --denoised-copy-ratios {output.denoised} \
            > {log} 2>&1"

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## Collect Allelic Counts
## Counts reference and alternative alleles at common germline variant sites
## See: https://gatkforums.broadinstitute.org/dsde/discussion/11683/
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule collectalleliccounts:
    input:
        "results/bqsr/{aliquot_id}.realn.mdup.bqsr.bam"
    output:
        "results/collectalleliccounts/{aliquot_id}.allelicCounts.tsv"
    params:
        mem = CLUSTER_META["collectalleliccounts"]["mem"]
    threads:
        CLUSTER_META["collectalleliccounts"]["ppn"]
    log:
        "logs/collectalleliccounts/{aliquot_id}.log"
    benchmark:
        "benchmarks/collectalleliccounts/{aliquot_id}.txt"
    message:
        "Collect allelic counts\n"
        "Aliquot: {wildcards.aliquot_id}"
    shell:
        "gatk --java-options -Xmx{params.mem}g CollectAllelicCounts \
            -I {input} \
            -L {config[tiny_vcf]} \
            -R {config[reference_fasta]} \
            -O {output} \
            > {log} 2>&1"

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## Model segments
## Use a guassian-kernel binary-segmentation algorithm to group contiguouis copy ratios into segments
## See: https://gatkforums.broadinstitute.org/dsde/discussion/11683/
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule modelsegments:
    input:
        tumor_denoised = lambda wildcards: "results/denoisereadcounts/{aliquot_id}.denoisedCR.tsv".format(aliquot_id=PAIRS_DICT[wildcards.pair_id]["tumor_aliquot_id"]),
        tumor_counts = lambda wildcards: "results/collectalleliccounts/{aliquot_id}.allelicCounts.tsv".format(aliquot_id=PAIRS_DICT[wildcards.pair_id]["tumor_aliquot_id"]),
        normal_counts = lambda wildcards: "results/collectalleliccounts/{aliquot_id}.allelicCounts.tsv".format(aliquot_id=PAIRS_DICT[wildcards.pair_id]["normal_aliquot_id"])
    output:
        "results/modelsegments/{pair_id}.modelBegin.seg",
        "results/modelsegments/{pair_id}.modelFinal.seg",
        "results/modelsegments/{pair_id}.cr.seg",
        "results/modelsegments/{pair_id}.modelBegin.af.param",
        "results/modelsegments/{pair_id}.modelBegin.cr.param",
        "results/modelsegments/{pair_id}.modelFinal.af.param",
        "results/modelsegments/{pair_id}.modelFinal.cr.param",
        "results/modelsegments/{pair_id}.hets.normal.tsv",
        "results/modelsegments/{pair_id}.hets.tsv"
    params:
        mem = CLUSTER_META["modelsegments"]["mem"],
        outputdir = "results/modelsegments/{wildcards.pair_id}",
        outputprefix = "File_{wildcards.pair_id}_"
    threads:
        CLUSTER_META["modelsegments"]["ppn"]
    log:
        "logs/modelsegments/{pair_id}.log"
    benchmark:
        "benchmarks/modelsegments/{pair_id}.txt"
    message:
        "Model segments\n"
        "Pair ID: {wildcards.pair_id}"
    shell:
        "gatk --java-options -Xmx{params.mem}g ModelSegments \
            --denoised-copy-ratios {input.tumor_denoised} \
            --allelic-counts {input.tumor_counts} \
            --normal-allelic-counts {input.normal_counts} \
            --output {params.outputdir} \
            --output-prefix {params.outputprefix} \
            > {log} 2>&1"

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## Call Segments
## Systematic calling of copy-neutral, aplified and deleted segments
## See: https://gatkforums.broadinstitute.org/dsde/discussion/11683/
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

rule callsegments:
    input:
        "results/modelsegments/{pair_id}.cr.seg"
    output:
        "results/callsegments/{pair_id}.called.seg"
    params:
        mem = CLUSTER_META["callsegments"]["mem"]
    threads:
        CLUSTER_META["callsegments"]["ppn"]
    log:
        "logs/callsegments/{pair_id}.log"
    benchmark:
        "benchmarks/callsegments/{pair_id}.txt"
    message:
        "Call segments\n"
        "Pair ID: {wildcards.pair_id}"
    shell:
        "gatk --java-options -Xmx{params.mem}g CallCopyRatioSegments \
            --input {input} \
            --output {output} \
            > {log} 2>&1"

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 
## Plot modeled segments
## Use a guassian-kernel binary-segmentation algorithm to group contiguouis copy ratios into segments
## See: https://gatkforums.broadinstitute.org/dsde/discussion/11683/
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## 

# rule plotmodeledsegments:
#     input:
#         tumor_denoised = lambda wildcards: "results/denoisereadcounts/{aliquot_id}.denoisedCR.tsv".format(aliquot_id=PAIRS_DICT[wildcards.pair_id]["tumor_aliquot_id"]),
#         tumor_counts = lambda wildcards: "results/collectalleliccounts/{aliquot_id}.allelicCounts.tsv".format(aliquot_id=PAIRS_DICT[wildcards.pair_id]["tumor_aliquot_id"]),
#         tumor_segments = "results/modelsegments/{pair_id}.modelFinal.seg"
#     output:
#         xx
#     params:
#         mem = CLUSTER_META["plotmodeledsegments"]["mem"],
#         outputdir = "results/plotmodeledsegments/{pair_id}",
#         outputprefix = "{pair_id}"
#     threads:
#         CLUSTER_META["plotmodeledsegments"]["ppn"]
#     log:
#         "logs/plotmodeledsegments/{pair_id}.log"
#     benchmark:
#         "benchmarks/plotmodeledsegments/{pair_id}.txt"
#     message:
#         "Plot modelled segments\n"
#         "Pair ID: {wildcards.pair_id}"
#     shell:
#         "gatk --java-options -Xmx{params.mem}g PlotModeledSegments \
#             --denoised-copy-ratios {input.tumor_denoised} \
#             --allelic-counts {input.tumor_counts} \
#             --segments {input.tumor_segments}} \
#             --sequence-dictionary {config[reference_dict]} \
#             --minimum-contig-length 46709983 \
#             --output {params.outputdir} \
#             --output-prefix {params.outputprefix} \
#             > {log} 2>&1"

## END ##