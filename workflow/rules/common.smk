# import basic packages
from snakemake.utils import validate


# validate config file
validate(config, schema="../schemas/config.schema.yaml")
