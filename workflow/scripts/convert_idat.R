#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(sesame)
})

# args <- commandArgs(trailingOnly = TRUE)

# if (length(args) < 2) {
#   stop(
#     paste(
#       "Usage:",
#       "Rscript convert_idat.R <idat_dir> <out_dir> <sample_sheet_path>"
#     )
#   )
# }

idat_dir  <- snakemake@input[["idat_dir"]]
out_dir   <- snakemake@output[["out_dir"]]
sample_sheet_path <- snakemake@input[["sample_sheet_path"]]
prep_code <- "QCDPB"

if (!file.exists(sample_sheet_path)) {
  stop("Sample sheet does not exist: ", sample_sheet_path)
}

if (!dir.exists(idat_dir)) {
  stop("Input directory does not exist: ", idat_dir)
}

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Read sample sheet
samples <- read.csv(sample_sheet_path, stringsAsFactors = FALSE, check.names = FALSE)

if (nrow(samples) == 0) {
  stop("Sample sheet is empty: ", sample_sheet_path)
}

if ("idat_prefix" %in% colnames(samples)) {

  # The sample sheet directly provides the IDAT prefix
  prefixes_raw <- samples$idat_prefix

  if ("sample_id" %in% colnames(samples)) {
    sample_ids <- samples$sample_id
  } else {
    sample_ids <- basename(prefixes_raw)
  }

} else if (all(c("Sentrix_ID", "Sentrix_Position") %in% colnames(samples))) {

  # The sample sheet has Illumina Sentrix columns
  prefixes_raw <- paste0(samples$Sentrix_ID, "_", samples$Sentrix_Position)

  if ("Sample_Name" %in% colnames(samples)) {
    sample_ids <- samples$Sample_Name
  } else {
    sample_ids <- prefixes_raw
  }

} else {

  # Unsupported sample sheet format
  stop(
    paste(
      "Sample sheet must contain either:",
      "1) columns 'sample_id' and 'idat_prefix',",
      "or 2) columns 'Sentrix_ID' and 'Sentrix_Position' ",
      "(optionally 'Sample_Name')."
    )
  )
}

sample_ids <- as.character(sample_ids)
prefixes_raw <- as.character(prefixes_raw)

# Check for missing values
if (any(is.na(sample_ids)) || any(sample_ids == "")) {
  stop("Some sample IDs are missing or empty in the sample sheet.")
}

if (any(is.na(prefixes_raw)) || any(prefixes_raw == "")) {
  stop("Some IDAT prefixes are missing or empty in the sample sheet.")
}

# Check for duplicate sample IDs, because they would overwrite files
if (anyDuplicated(sample_ids)) {
  dupes <- unique(sample_ids[duplicated(sample_ids)])
  stop("Duplicate sample_id values found: ", paste(dupes, collapse = ", "))
}

# Build prefixes
prefixes <- ifelse(
  grepl("^/", prefixes_raw),
  prefixes_raw,
  file.path(idat_dir, prefixes_raw)
)

message("Found ", length(prefixes), " sample(s) in the sample sheet.")

message("Using sesame prep code: ", prep_code)

for (i in seq_along(prefixes)) {

  # Current sample information
  prefix <- prefixes[i]
  sample_id <- sample_ids[i]

  # Construct the expected Green and Red filenames
  grn1 <- paste0(prefix, "_Grn.idat")
  grn2 <- paste0(prefix, "_Grn.idat.gz")
  red1 <- paste0(prefix, "_Red.idat")
  red2 <- paste0(prefix, "_Red.idat.gz")

  # Check that both the Green and Red files exist
  has_grn <- file.exists(grn1) || file.exists(grn2)
  has_red <- file.exists(red1) || file.exists(red2)

  if (!has_grn || !has_red) {
    stop(
      paste0(
        "Missing IDAT pair for sample '", sample_id, "' with prefix '", prefix, "'. ",
        "Expected files like: ",
        basename(prefix), "_Grn.idat and ", basename(prefix), "_Red.idat"
      )
    )
  }

  # Output filename for this sample
  out_csv <- file.path(out_dir, paste0(sample_id, ".beta.csv"))

  message("Processing: ", sample_id)

  # Read one Green/Red IDAT pair
  sdf <- readIDATpair(prefix)

  # Compute beta values
  betas <- openSesame(sdf, prep = prep_code)

  # Convert the beta vector into a table
  beta_df <- data.frame(
    probe_id = names(betas),
    beta = as.numeric(betas),
    check.names = FALSE
  )

  write.csv(beta_df, file = out_csv, row.names = FALSE, quote = FALSE)

  message("Wrote: ", out_csv)
}

message("Done.")