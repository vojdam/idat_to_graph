"""
Script for generating a UMAP graph from beta value CSVs.

Intented to be used as a part of a Snakemake pipeline.
"""

import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

from sklearn.decomposition import PCA
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler
import umap

# parameters
sample_folder = snakemake.input[0]
sample_sheet_path = snakemake.params["sample_sheet"]

TOP_VARIABLE_CPGS = 10000
PCA_COMPONENTS = 50

UMAP_NEIGHBORS = 15
UMAP_MIN_DIST = 0.1
RANDOM_STATE = 42

# load sample sheet
sample_sheet = pd.read_csv(sample_sheet_path)

sample_sheet["sample_id"] = sample_sheet["sample_id"].astype(str)

sample_to_diag = dict(zip(sample_sheet["sample_id"], sample_sheet["diagnosis"]))

# load beta CSV files
beta_values = []

for csv_file in os.listdir(sample_folder):
    if not csv_file.endswith(".csv"):
        continue
    sample_id = os.path.basename(csv_file)
    full_path = os.path.join(sample_folder, csv_file)
    temp_df = pd.read_csv(full_path)
    temp_df = temp_df.set_index(temp_df.columns[0])
    temp_df.columns = [sample_id]
    beta_values.append(temp_df)
beta_matrix = pd.concat(beta_values, axis=1)

print("Matrix shape (CpGs x samples):", beta_matrix.shape)

# impute missing values
imputer = SimpleImputer(strategy="mean")

beta_matrix = pd.DataFrame(
    imputer.fit_transform(beta_matrix),
    index=beta_matrix.index,
    columns=beta_matrix.columns,
)

# feature selection
variances = beta_matrix.var(axis=1)

top_cpgs = variances.sort_values(ascending=False).head(TOP_VARIABLE_CPGS).index

beta_filtered = beta_matrix.loc[top_cpgs]

# transpose → samples x CpGs
X = beta_filtered.T

# scale data
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# PCA reduction
pca = PCA(n_components=PCA_COMPONENTS)

X_pca = pca.fit_transform(X_scaled)

print("PCA shape:", X_pca.shape)

# UMAP
reducer = umap.UMAP(
    n_neighbors=UMAP_NEIGHBORS,
    min_dist=UMAP_MIN_DIST,
    n_components=2,
    random_state=RANDOM_STATE,
)

X_umap = reducer.fit_transform(X_pca)

# prepare plot data
diagnoses = [sample_to_diag[s.split(".")[0]] for s in X.index]

plot_df = pd.DataFrame(
    {"UMAP1": X_umap[:, 0], "UMAP2": X_umap[:, 1], "Diagnosis": diagnoses}
)

# plot
plt.figure(figsize=(8, 6))

sns.scatterplot(
    data=plot_df,
    x="UMAP1",
    y="UMAP2",
    hue="Diagnosis",
    palette="tab10",
    s=120,
    edgecolor="black",
    linewidth=0.3,
    alpha=0.9,
)

plt.title("UMAP of DNA methylation samples")
plt.xlabel("UMAP-1")
plt.ylabel("UMAP-2")

plt.legend(bbox_to_anchor=(1.05, 1), loc="upper left")

plt.tight_layout()

plt.savefig(snakemake.output[0], dpi=300)

plt.close()
