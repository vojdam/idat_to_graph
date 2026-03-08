# convert idat files to csvs of beta values
rule convert_idat:
    input:
        idat_dir=lookup(within=config, dpath="sample_folder"),
        sample_sheet_path=lookup(within=config, dpath="sample_sheet")
    output:
        out_dir=directory("results/convert_idat/beta_values")
    conda:
        "../envs/convert_idat.yaml"
    log:
        "results/convert_idat/convert_idat.log"
    script:
        "../scripts/convert_idat.R"


# generate tsne from beta values
rule generate_tsne:
    input:
        rules.convert_idat.output.out_dir,
    output:
        "results/generate_tsne/tsne.pdf",
    conda:
        "../envs/generate_tsne.yaml"
    log:
        "results/generate_tsne/generate_tsne.log",
    script:
        "../scripts/generate_tsne.py"
