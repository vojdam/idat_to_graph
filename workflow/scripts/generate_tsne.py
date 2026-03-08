"""
Script for generating a tSNE graph from beta value CSVs.

Intented to be used as a part of a Snakemake pipeline.
"""

import os
import pandas as pd
from sklearn.decomposition import PCA
from sklearn.manifold import TSNE
import seaborn as sns
import matplotlib.pyplot as plt
from sklearn.impute import SimpleImputer

# set variables
sample_folder = snakemake.input[0]
TOP_VARIABLE_CPGS = 10000
PCA_COMPONENTS = 50
TSNE_PERPLEXITY = 30
RANDOM_STATE = 42

# generate dataframe
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
beta_values_df = pd.concat(beta_values, axis=1)

# handle misssing values
imputer = SimpleImputer(strategy="mean")
beta_matrix_imputed = pd.DataFrame(
    imputer.fit_transform(beta_values_df),
    index=beta_values_df.index,
    columns=beta_values_df.columns,
)

# select most variant CpGs
variances = beta_matrix_imputed.var(axis=1)

top_cpgs = variances.sort_values(ascending=False).head(TOP_VARIABLE_CPGS).index

beta_filtered = beta_matrix_imputed.loc[top_cpgs]

print("Filtered matrix:", beta_filtered.shape)

# transpose -> samples x features
X = beta_filtered.T

# PCA dimensionality reduction
pca = PCA(n_components=PCA_COMPONENTS)
X_pca = pca.fit_transform(X)

print("PCA output:", X_pca.shape)

# tSNE generation
tsne = TSNE(
    n_components=2, perplexity=TSNE_PERPLEXITY, random_state=RANDOM_STATE, max_iter=1000
)

X_tsne = tsne.fit_transform(X_pca)

# load sample sheet

sample_sheet = pd.read_csv(snakemake.params["sample_sheet"])

# create dictionary: sample -> diagnosis
sample_to_diag = dict(zip(sample_sheet["sample_id"], sample_sheet["diagnosis"]))

# create list of diagnoses aligned with X index
diagnoses = [sample_to_diag[s.split(".")[0]] for s in X.index]

# tSNE plot
tsne_df = pd.DataFrame({
    "tSNE1": X_tsne[:,0],
    "tSNE2": X_tsne[:,1],
    "Diagnosis": diagnoses
})

plt.figure(figsize=(8,6))

sns.scatterplot(
    data=tsne_df,
    x="tSNE1",
    y="tSNE2",
    hue="Diagnosis",
    palette="tab10",
    s=80
)

plt.title("t-SNE of DNA methylation samples")
plt.xlabel("tSNE-1")
plt.ylabel("tSNE-2")

plt.legend(bbox_to_anchor=(1.05,1), loc="upper left")

plt.tight_layout()
plt.savefig(snakemake.output[0], dpi=300)
