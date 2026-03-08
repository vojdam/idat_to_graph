suppressPackageStartupMessages({
  library(sesame)
  library(sesameData)
})

if (!exists("snakemake")) {
  stop("This script must be run via Snakemake using the `script:` directive.")
}

sesameDataCache()

idat_dir <- snakemake@input[["idat_dir"]]
out_dir <- snakemake@output[["out_dir"]]
sample_sheet_path <- snakemake@input[["sample_sheet_path"]]
prep_code <- "QCDPB"

if (!file.exists(sample_sheet_path)) {
  stop("Sample sheet does not exist: ", sample_sheet_path)
}

if (!dir.exists(idat_dir)) {
  stop("Input directory does not exist: ", idat_dir)
}

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

samples <- read.csv(sample_sheet_path, stringsAsFactors = FALSE, check.names = FALSE)

if (nrow(samples) == 0) {
  stop("Sample sheet is empty: ", sample_sheet_path)
}

if ("idat_prefix" %in% colnames(samples)) {
  prefixes_raw <- as.character(samples$idat_prefix)

  if ("sample_id" %in% colnames(samples)) {
    sample_ids <- as.character(samples$sample_id)
  } else {
    sample_ids <- basename(prefixes_raw)
  }

} else if (all(c("Sentrix_ID", "Sentrix_Position") %in% colnames(samples))) {
  prefixes_raw <- paste0(samples$Sentrix_ID, "_", samples$Sentrix_Position)

  if ("Sample_Name" %in% colnames(samples)) {
    sample_ids <- as.character(samples$Sample_Name)
  } else {
    sample_ids <- prefixes_raw
  }

} else {
  stop(
    paste(
      "Sample sheet must contain either:",
      "1) 'idat_prefix' (and optionally 'sample_id'),",
      "or 2) 'Sentrix_ID' and 'Sentrix_Position' (optionally 'Sample_Name')."
    )
  )
}

sample_ids <- trimws(sample_ids)
prefixes_raw <- trimws(prefixes_raw)

if (any(is.na(sample_ids)) || any(sample_ids == "")) {
  stop("Some sample IDs are missing or empty in the sample sheet.")
}

if (any(is.na(prefixes_raw)) || any(prefixes_raw == "")) {
  stop("Some IDAT prefixes are missing or empty in the sample sheet.")
}

if (anyDuplicated(sample_ids)) {
  dupes <- unique(sample_ids[duplicated(sample_ids)])
  stop("Duplicate sample_id values found: ", paste(dupes, collapse = ", "))
}

# Prevent sample IDs from creating invalid / nested output paths
if (any(grepl("[/\\\\]", sample_ids))) {
  bad <- unique(sample_ids[grepl("[/\\\\]", sample_ids)])
  stop("These sample IDs contain / or \\ and cannot be used as filenames: ",
       paste(bad, collapse = ", "))
}

# Build full prefixes more safely than with ifelse()
prefixes <- prefixes_raw

# Treat Unix absolute paths (/...) and Windows absolute paths (C:\... or C:/...) as absolute
is_absolute <- grepl("^(/|[A-Za-z]:[/\\\\])", prefixes_raw)
prefixes[!is_absolute] <- file.path(idat_dir, prefixes_raw[!is_absolute])

message("Found ", length(prefixes), " sample(s) in the sample sheet.")
message("Using sesame prep code: ", prep_code)

for (i in seq_along(prefixes)) {
  prefix <- prefixes[i]
  sample_id <- sample_ids[i]

  grn1 <- paste0(prefix, "_Grn.idat")
  grn2 <- paste0(prefix, "_Grn.idat.gz")
  red1 <- paste0(prefix, "_Red.idat")
  red2 <- paste0(prefix, "_Red.idat.gz")

  has_grn <- file.exists(grn1) || file.exists(grn2)
  has_red <- file.exists(red1) || file.exists(red2)

  if (!has_grn || !has_red) {
    stop(
      paste0(
        "Missing IDAT pair for sample '", sample_id,
        "' with prefix '", prefix, "'."
      )
    )
  }

  out_csv <- file.path(out_dir, paste0(sample_id, ".beta.csv"))
  message("Processing: ", sample_id)

  sdf <- readIDATpair(prefix)
  betas <- openSesame(sdf, prep = prep_code)

  beta_df <- data.frame(
    probe_id = names(betas),
    beta = as.numeric(betas),
    check.names = FALSE
  )

  write.csv(beta_df, file = out_csv, row.names = FALSE, quote = FALSE)
  message("Wrote: ", out_csv)
}

message("Done.")