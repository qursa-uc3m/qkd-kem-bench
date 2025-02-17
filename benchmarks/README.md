# QKD-KEM Provider Benchmarking Suite

This repository contains tools and scripts for analyzing the performance our QKD-KEM Provider, and allows for comparison with the standard OQS Provider. The suite evaluates performance in two scenarios:

1. **Isolated KEM Operations**: Measure the execution tme (ms) for:
    - Key generation
    - Encapsulation
    - Decapsulation

2. **TLS Integration**: Measures successful TLS Handshake completion time (ms).

## Directory Structure

Raw benchmark data is collected using the dedicated scripts located in the root `scripts/` directory. These scripts are designed to be run from the repository's root directory and generate CSV files containing timing measurements of the chosen provider, storing them in the `benchmarks/data/` folder. The `benchmarks/` directory also contains two scripts and a Python noteboook which you can use for analyzing the data.    

```bash
benchmarks/
├── data/          # Benchmark CSV output files
├── plots/         # Generated plots and visualizations
├── config.py      # Configuration parameters
└── functions.py   # Analysis and visualization functions
```


## Prerequisites

### System Requirements

You might need to install LaTeX dependencies for nice fonts for your plots. Otherwise, you can set to False the LaTeX option (text.usetex) in [config.py](./config.py).
```bash
sudo apt-get install texlive-latex-extra dvipng cm-super
```

### Python environment

It is convenient to create and configure a Python environment (virtual env or conda):
```bash
# Create virtual environment 
python -m venv <env_name>
source <env_name>/bin/activate  # or conda activate your_env

# Install dependencies
pip install -r benchmarks/requirements.txt
```

## Running the Bechmark suite

### 1. Environment Setup

Configure OpenSSL and paths environment variables. Depending on the API backend type you are working with, you might set:
```bash
 # For QuKayDee backend. Check for your <id_number> in the CA certificate you download from their site.
export QKD_BACKEND=qukaydee && export ACCOUNT_ID="<id_number>" 

# For Cerberis-XGR backend.
export QKD_BACKEND=cerberis-xgr
```

From the repository's root dir:
```bash
source scripts/oqs_env.sh [OPENSSL_PATH]
```
- If `OPENSSL_INSTALL` is set: Uses system installation.
- If `.local/bin/openssl`exists: Uses self-contained setup within the repository's root.
- Otherwise: Uses manual installation path (default to `/opt/oqs_openssl3`)

### 2. Isolated KEM Operations Benchmarks

```bash
./scripts/run_qkd_kem_bench.sh [OPTIONS]

Options:
  -i, --iterations N    Number of iterations (required)
  -p, --provider P      Provider type (qkd or oqs) [default: qkd]
  -d, --delay D         Delay between iterations in seconds [default: 0]
```

### 3. TLS Handshake Benchmarks

```bash
./scripts/run_tls_bench.sh [OPTIONS]

Options:
  -i, --iterations N    Number of iterations (default: 10)
  -p, --provider P      Provider type (qkd or oqs) [default: oqs]
  -d, --delay D         Delay between combinations in seconds (default: 0)
```

## Data Analysis

### CSV Output format

The CSV files have the following column structure:

```csv
# Isolated KEM Operations file
Algorithm,Iteration,KeyGen(ms),Encaps(ms),Decaps(ms)

# TLS Handshake file
KEM,Cert,Iteration,Time
```

### Supported Algorithms

Currently, we have support for the following KEM families:

- MLKEM (512, 768, 1024)
- BIKE (L1, L3, L5)
- FrodoKEM (640, 976, 1344; with AES/SHAKE variants)
- HQC (128, 192, 256)

For the TLS Handshake Benchmarks, we can use the following signature algorithms:

- RSA (2048, 3072, 4096)
- MLDSA (44, 65, 87)
- Falcon (512, 1024)
- SPHINCS+ (To be Added Manually)

### Running the analysis

You can run the analysis using the Python scripts in `benchmarks` in a Jupyter notebook
```bash
cd benchmarks
jupyter notebook
```
If you want to create your own notebook, import the utility functions and configuration variables
```python
from functions import *
import config as cfg
```

#### Analysis scripts

The Python analysis suite consists in (work in progress):

__`config.py`__: Defines global configurations including:

- KEM algorithms families and their variants.
- Standard-to-QKD-KEM mappings.
- Plotting style parameters.
- Font configurations.
- Axes styling parameters.

__`functions.py`__: Provides functions for the statistical analysis and data visualization:

Data processing and computations:
- `kem_data_process()`: Reads and process the .csv files to Pandas Data Frames.
- `kem_data_summary()`: Computes the summary statistics for the KEM operations.
- `compute_ops_percent()`: calculates the weight of each operation with respect to the total time, in percentage.
- `tls_data_summary()`: Computes the summary statistics for the TLS benchmark data.

Data Visualization:
- `plot_kem_times()`: Basic KEM operation timings.
- `plot_kem_total_times()`: Agreggated timing analysis.
- `plot_kem_fast()`: For plotting "faster" KEM variants. You can select the name of the last       algorithm plotted. 
- `plot_kem_family()`: Plot only a selected family of KEM algorithms.
- `plot_ops_percent()`: Operation percentage breakdown
- `plot_kem_comparison()`: For QKD-KEM vs OQS Provider comparison.
- `plot_tls_kem_families()`: TLS Performance by KEM family, for a given signature algorithm.
- `plot_tls_certs_families()`: TLS Performance by signature algorithm, for a given KEM type.

Details about function usage and input variables can be found in the function docstrings.

### Notes

Several important notes regarding the analysis:

- The analysis (optionally) excludes the first few iterations as warmup
- Times are reported in miliseconds (ms)
- Summary statistics includes: __mean, standard deviation, min and max values__. 
- Generated plots use LaTeX formatting for consistent, publication-ready output. Make sure you have a working LaTeX distribution availble in your machine and that Matplotlib can find it.
