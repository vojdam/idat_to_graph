#!/usr/bin/env bash
set -euo pipefail

Rscript -e 'BiocManager::install("preprocessCore", configure.args="--disable-threading", force=TRUE, ask=FALSE, update=FALSE)'
Rscript -e 'library(sesameData); sesameDataCache()'