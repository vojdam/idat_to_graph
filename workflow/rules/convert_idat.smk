rule idat_convertsion:
    input:
        script = "scripts/convert_idat.R"
    output:
        beta_csvs = "results/idat_conversion/beta_csvs/"
    params:
        idat_dir = lookup(within=config, dpath="sample_folder")
        out_dir = "results/idat_conversion/beta_values"
        sample_sheet_path = lookup(within=config, dpath="sample_sheet")
    conda:
        "envs/convert_idat.yaml"
    log:
        "results/idat_conversion/sesame.log"
    shell:
        """
        mkdir -p {params.out_dir}
        Rscript {input.script} {params.idat_dir} {params.out_dir} {params.sample_sheet_path}
        touch {output.done}
        """