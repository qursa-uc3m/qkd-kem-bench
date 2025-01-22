# QKD-KEM Provider Benchmarking Analysis

This directory contains tools and scripts for analyzing the performance of both the QKD-KEM provider and the standard OQS provider. The analysis focuses on three key metrics:
- Key generation time (ms)
- Encapsulation time (ms)
- Decapsulation time (ms)

## Directory Structure
```bash
benchmarks/
├── data/          # Contains benchmark CSV output files
└── plots/         # Generated plots and visualizations
```

## Analysis Components

Raw benchmark data is collected using the dedicated script located in the root `scripts/` directory. The script generates CSV files containing timing measurements of the chosen provider. 

### Output format

The CSV files have the following column structure:

- `Algorithm`: Name of the KEM algorithm. If generated for the QKD-KEM provider, all these names will start by `qkd_`.
- `Iteration`: Benchmark iteration number. 
- `KeyGen(ms)`: Key Generation time in miliseconds.
- `Encaps(ms)`: Encapsulation time in miliseconds.
- `Decaps(ms)`: Decapsulation time in miliseconds.

### Analysis scripts

__`config.py`__: Defines global configurations including:

- KEM algorithms families and their variants.
- Standard-to-QKD-KEM mappings.
- Plotting style parameters.
- Font configurations.
- Axes styling parameters.

__`functions.py`__: Provides functions for:
- Data processing and statistical analysis.
- Visualization of benchmark results.
- Comparative analysis between providers.

### Key visualizations

The analysis produces several types of plots (work in progress):

1. Individual algorithm performance breakdown.
2. Family-wise comparisons.
3. Operation percentage analysis.
4. Standard vs QKD implementation comparisons.

### Supported KEM families

The analysis covers the following KEM families. 

- Kyber (512, 768, 1024)
- ML-KEM (512, 768, 1024)
- BIKE (L1, L3, L5)
- FrodoKEM (640, 976, 1344, with AES/SHAKE variants)
- HQC (128, 192, 256)

## Running the analysis

The statistical analysis and data visualization operations are done in Python. You might need (or prefer) to set up a dedicated Python environment for this project. Please, check the `requirements.txt` for reference or run
```bash
pip install -r requirements.txt
```

1. Collect the data. From the project's root directory, run:

```bash
# Run benchmarks with 100 iterations for each provider
./scripts/run_qkd_kem_bench.sh -b 100 -p qkdkemprovider
./scripts/run_qkd_kem_bench.sh -b 100 -p oqs
```

2. Analyze the data:
```bash
cd benchmarks
jupyter notebook data_analysis.ipynb
```
Or load the notebook with your favourite IDE. This notebook will make use of the utility functions defined in `functions.py` to perform the analysis and visualize the data:

- Load and process the benchmark data. The data processing will add an additional column with the Total Time of the KEM operation.
- Generate the summary statistics.
- Generate visualization plots based upon the summary statistics. 
- Provide comparative analyses. 

### Notes

Several important notes regarding the analysis:

- The analysis excludes the first few iterations as warmup
- Times are reported in miliseconds (ms)
- Summary statistics includes: __mean, standard deviation, min and max values__. 
- Generated plots use LaTeX formatting for consistent, publication-ready output. Make sure you have a working LaTeX distribution availble in your machine and that Matplotlib can find it. See the `requirements.txt` file for reference about what you need to install in your system.
