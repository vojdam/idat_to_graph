## Workflow overview

This workflow is used to create clustering tSNE and UMAP graphs from IDAT files obtained using sequencing on Illumina chips.
The workflow is built using [snakemake](https://snakemake.readthedocs.io/en/stable/) and consists of the following steps:

1. Convert the IDAT files to corresponding CSVs of beta values
2. Construct the tSNE graph
3. Construct the UMAP graph

## Running the workflow

### Input data

This workflow uses IDAT file pairs (`_Grn` and `_Red`); the file extensions should be either `.idat.gz` or `.idat`.
The sample sheet has the following layout:

| sample_id  | diagnosis | idat_prefix |
| ------- | --------- | --------- |
| REFERENCE_SAMPLE 1 | Control (muscle tissue) | 201904410008_R06C01 |
| REFERENCE_SAMPLE 2 | Control (muscle tissue) | 201904410008_R05C01 |

### Parameters

This table lists all parameters that can be used to run the workflow.

| parameter          | type | details                               | default                        |
| ------------------ | ---- | ------------------------------------- | ------------------------------ |
| **sample_sheet**   |      |                                       |                                |
| path               | str  | path to sample sheet, mandatory       | ".test/config/sample_sheet.csv"|
| **sample_folder**  |      |                                       |                                |
| path               | str  | path to sample containing folder mandatory | ".test/config/samples/"   |
