import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from matplotlib.ticker import AutoMinorLocator, MultipleLocator, LogLocator, NullFormatter
import os

from config import (KEM_FAMILIES, KEM_COMPARISON, 
                    FONT_SIZES, AXES_STYLE)

# -- -- DATA PROCESSING -- -- #

def kem_data_process(csv_path):
    """
    Reads a CSV file and processes KEM algorithm data based on the file type.
    For OQS data, includes only base algorithms (without prefixes like p256_, x25519_, etc.)
    For QKDKEMProvider data, includes only QKD prefixed algorithms.
    
    Args:
        csv_path (str): Path to the CSV file. Expected to contain either 'oqs' 
                       or 'qkdkemprovider' in the filename.
    
    Returns:
        pd.DataFrame: DataFrame with added TotalTime column
    """
    # Read CSV file
    df = pd.read_csv(csv_path)
    
     # Apply filtering only for OQS data
    if 'oqs' in csv_path.lower():
        # Standard OQS data - exclude:
        # 1. Algorithms with underscore
        # 2. SecP256r1MLKEM768 and X25519MLKEM768
        exclude_list = ['SecP256r1MLKEM768', 'X25519MLKEM768']
        df = df[
            (~df['Algorithm'].str.contains('_')) & 
            (~df['Algorithm'].isin(exclude_list))
        ].copy()
    
    # Add TotalTime column
    df['TotalTime(ms)'] = (df['KeyGen(ms)'] +
                          df['Encaps(ms)'] +
                          df['Decaps(ms)'])
    
    return df

def kem_data_summary(df, warmup=3):
    """
    Generates summary statistics for each algorithm in the DataFrame, excluding warmup iterations.
    
    Args:
        df (pd.DataFrame): Input DataFrame with KEM measurements
        warmup (int): Number of initial iterations to exclude (default: 3)
        
    Returns:
        pd.DataFrame: Summary statistics DataFrame with columns for count, mean, std, min, max
    """
    # Filter out warmup iterations
    df_filtered = df[df['Iteration'] > warmup]
    
    # Group by Algorithm and calculate statistics
    summary_stats = df_filtered.groupby('Algorithm').agg({
        'Iteration': 'count',
        'KeyGen(ms)': ['mean', 'std', 'min', 'max'],
        'Encaps(ms)': ['mean', 'std', 'min', 'max'],
        'Decaps(ms)': ['mean', 'std', 'min', 'max'],
        'TotalTime(ms)': ['mean', 'std', 'min', 'max']
    }).round(3)
    
    # Flatten column names
    summary_stats.columns = [
        f'{col[0]}_{col[1]}' if col[1] else col[0] 
        for col in summary_stats.columns
    ]
    
    # Rename count column
    summary_stats = summary_stats.rename(columns={'Iteration_count': 'NumIterations'})
    
    return summary_stats

def compute_ops_percent(df):
    """
    Calculates the percentage contribution of each operation to total time.
    
    Args:
        df: DataFrame with mean operation times
        
    Returns:
        DataFrame with operation percentages
    """
    # Calculate percentages
    ops = ['KeyGen(ms)_mean', 'Encaps(ms)_mean', 'Decaps(ms)_mean']
    percentages = df[ops].copy()
    
    # Convert to percentages
    total = percentages.sum(axis=1)
    for col in ops:
        percentages[col] = (percentages[col] / total) * 100
        
    return percentages

def tls_data_summary(csv_path):
    """
    Reads and processes TLS benchmark data from a CSV file.
    Organizes data by KEM family and certificate type.
    
    Args:
        csv_path (str): Path to the CSV file. Expected to contain either 'oqs' 
                       or 'qkd' in the filename.
    
    Returns:
        pd.DataFrame: DataFrame with summary statistics, properly indexed and sorted
    """
    # Read CSV file
    df = pd.read_csv(csv_path)
    
    # Determine provider type from filename
    is_qkd = 'qkd' in csv_path.lower()
    
    # Group by KEM and Certificate combination
    grouped_stats = df.groupby(['KEM', 'Cert']).agg({
        'Time': ['count', 'mean', 'std', 'min', 'max']
    }).round(3)
    
    # Flatten column names
    grouped_stats.columns = [
        f'Time_{col}' for col in ['count', 'mean', 'std', 'min', 'max']
    ]
    
    # Sort by KEM family order defined in config
    def get_kem_family(kem):
        kem_name = kem.replace('qkd_', '') if is_qkd else kem
        for family, algs in KEM_FAMILIES.items():
            if any(kem_name.startswith(alg) for alg in algs):
                return family
        return 'unknown'
    
    # Add KEM family as a column for sorting
    grouped_stats['Family'] = [get_kem_family(kem) for kem, _ in grouped_stats.index]
    
    # Sort by family (using dict order), then KEM name, then certificate
    family_order = list(KEM_FAMILIES.keys())
    grouped_stats = grouped_stats.reset_index()
    grouped_stats['Family_order'] = grouped_stats['Family'].map(
        {fam: i for i, fam in enumerate(family_order)}
    )
    
    # Sort the DataFrame
    grouped_stats = grouped_stats.sort_values(
        ['Family_order', 'KEM', 'Cert']
    ).set_index(['KEM', 'Cert'])
    
    # Drop helper columns
    grouped_stats = grouped_stats.drop(['Family', 'Family_order'], axis=1)
    
    return grouped_stats

# -- -- DATA PLOTTING -- -- #

def apply_axes_style(ax, xlabel=None, ylabel=None, title=None):
    """
    Applies consistent styling to plot axes, supporting both linear and logarithmic scales.
    
    Args:
        ax: matplotlib axes object
        xlabel: x-axis label (optional)
        ylabel: y-axis label (optional)
        title: plot title (optional)
    """
    # Set labels and title if provided
    if xlabel:
        ax.set_xlabel(r'\textbf{' + xlabel + '}',
                     fontsize=FONT_SIZES['axes_label'],
                     labelpad=AXES_STYLE['label_pad'])
    if ylabel:
        ax.set_ylabel(r'\textbf{' + ylabel + '}',
                     fontsize=FONT_SIZES['axes_label'],
                     labelpad=AXES_STYLE['label_pad'])
    if title:
        ax.set_title(title,
                    fontsize=FONT_SIZES['axes_title'],
                    pad=20)

    # Configure grid
    ax.grid(AXES_STYLE['grid'],
            alpha=AXES_STYLE['grid_alpha'],
            zorder=0)
    ax.grid(which='minor',
            color=AXES_STYLE['grid_color'],
            linestyle=AXES_STYLE['grid_linestyle'],
            linewidth=AXES_STYLE['grid_linewidth'],
            alpha=0.3)

    # Configure ticks
    ax.tick_params(axis='both',
                  which='major',
                  length=AXES_STYLE['major_tick_length'],
                  width=AXES_STYLE['major_tick_width'],
                  labelsize=FONT_SIZES['tick_label'])
    ax.tick_params(axis='both',
                  which='minor',
                  length=AXES_STYLE['minor_tick_length'],
                  width=AXES_STYLE['minor_tick_width'])

    # Handle y-axis scale-specific configurations
    if ax.get_yscale() == 'log':
        # Configure log-scale specific locators and formatters for y-axis
        ax.yaxis.set_major_locator(LogLocator(base=10.0, numticks=15))
        ax.yaxis.set_minor_locator(LogLocator(base=10.0, subs=np.arange(2, 10) * 0.1, numticks=15))
        ax.yaxis.set_minor_formatter(NullFormatter())
    else:
        ax.yaxis.set_minor_locator(AutoMinorLocator())

    # Handle x-axis minor ticks
    if not ax.get_xscale() == 'log':
        ax.xaxis.set_minor_locator(AutoMinorLocator())
        


def plot_kem_times(input_df, error_suffix="_std", plot_title="kem_times.png", y_start=None, y_end=None, log_scale=False):
    """
    Plots KEM timing measurements (KeyGen, Encaps, Decaps) for different algorithms.
    
    Args:
        input_df: DataFrame containing the KEM timing data
        error_suffix: Suffix for error columns (default: "_std")
        plot_title: Output filename for the plot
        y_start: Starting point for y-axis (optional)
        y_end: End point for y-axis (optional)
        log_scale: Boolean to enable logarithmic scale on y-axis (default: False)
    """

    # Extract all algorithm names from KEM_FAMILIES
    algo_names = [alg for family in KEM_FAMILIES.values() for alg in family]

    # Check if the input_df index contains the 'qkd_' prefix
    has_qkd_prefix = any(idx.startswith('qkd_') for idx in input_df.index)
    
    # Add 'qkd_' prefix to algorithm names if necessary
    if has_qkd_prefix:
        algo_names = ['qkd_' + alg for alg in algo_names]
    
    # Filter the DataFrame based on the algorithm names
    filter_df = input_df[input_df.index.isin(algo_names)].copy()
    
    # Sort algorithms by total time
    #filter_df = filter_df.sort_values('TotalTime(ms)_mean')
    
    # Setup plot dimensions
    width = 0.25  # width of the bars
    algorithms = filter_df.index.tolist()  # algorithms are in the index
    x = np.arange(len(algorithms))  # label locations
    
    # Create color palette for the three operations
    colors = list(mcolors.LinearSegmentedColormap.from_list("", ["#9fcf69", "#33acdc"])(np.linspace(0, 1, 3)))
    
    # Create figure and axis
    fig, ax = plt.subplots(figsize=(20, 10))
     # Set plot title based on dataset type
    provider_title = "QKD-KEM Provider" if has_qkd_prefix else "OQS Provider"
    ax.set_title(provider_title, fontsize=FONT_SIZES['axes_title'], pad=20)
    
    # Set logarithmic scale if requested
    if log_scale:
        ax.set_yscale('log')
    
    # Plot bars for each operation
    operations = ['KeyGen(ms)', 'Encaps(ms)', 'Decaps(ms)']
    bars = []
    for i, (operation, color) in enumerate(zip(operations, colors)):
        mean_col = f"{operation}_mean"
        std_col = f"{operation}{error_suffix}"
        
        container = ax.bar(x + (i-1)*width, 
                         filter_df[mean_col],
                         width,
                         label=operation.replace('(ms)', ''),
                         color=color,
                         edgecolor='black',
                         linewidth=1,
                         yerr=filter_df[std_col],
                         capsize=3,
                         error_kw={'ecolor': 'black'},
                         zorder=3)
        
        # Style error bars
        if error_suffix:
            for line in container.errorbar.lines[2]:
                line.set_linestyle('dashed')
                line.set_linewidth(0.75)
        
        bars.append(container)
    
    # Apply consistent styling
    apply_axes_style(ax, 
                    xlabel='Algorithm',
                    ylabel='Time (ms)')
    
    # Set x-ticks with LaTeX formatting for underscores
    ax.set_xticks(x)
    clean_labels = [alg.replace('qkd_', '') if has_qkd_prefix else alg for alg in algorithms]
    ax.set_xticklabels([label.replace('_', '\_') for label in clean_labels],
                   rotation=45,
                   horizontalalignment='right',
                   fontsize=FONT_SIZES['tick_label'])
    
    # Add grid with custom styling
    ax.grid(True, which='major', 
            alpha=AXES_STYLE['grid_alpha'], 
            zorder=0, 
            linewidth=AXES_STYLE['grid_linewidth'])
    ax.grid(True, which='minor', 
            color=AXES_STYLE['grid_color'],
            linestyle=AXES_STYLE['grid_linestyle'], 
            linewidth=AXES_STYLE['grid_linewidth'], 
            alpha=0.3)
    
    # Add legend below the title
    handles, labels = ax.get_legend_handles_labels()
    if labels:
        # Place legend below the plot title in a single row
        ax.legend(frameon=True, 
                 fontsize=FONT_SIZES['legend'],
                 loc='upper left',
                 bbox_to_anchor=(0, 1.01),
                 ncol=len(labels))
    
    # Add legend
    #ax.legend(loc='upper left',
    #         frameon=True, 
    #         fontsize=FONT_SIZES['legend'])
    
    # Set y-axis limits if specified
    if y_start or y_end is not None:
        ax.set_ylim(y_start, y_end)
    
    plt.tight_layout()
    
     # Handle plot saving and display
    if plot_title:  # Only save if plot_title is provided
        if not os.path.exists("./plots"):
            os.makedirs("./plots")
        plt.savefig(os.path.join(".", "plots", plot_title), bbox_inches='tight', dpi=300)
        plt.show()  # Always show the plot
    
# Additional utility function to create a simplified version showing only total times
def plot_kem_total_times(input_df, error_suffix="_std", plot_title="kem_total_times.png", y_start=None, log_scale=False):
    """
    Plots total KEM timing measurements for different algorithms.
    
    Args:
        input_df: DataFrame containing the KEM timing data
        error_suffix: Suffix for error columns (default: "_std")
        plot_title: Output filename for the plot
        y_start: Starting point for y-axis (optional)
    """

    # Extract all algorithm names from KEM_FAMILIES
    algo_names = [alg for family in KEM_FAMILIES.values() for alg in family]

    # Check if the input_df index contains the 'qkd_' prefix
    has_qkd_prefix = any(idx.startswith('qkd_') for idx in input_df.index)
    
    # Add 'qkd_' prefix to algorithm names if necessary
    if has_qkd_prefix:
        algo_names = ['qkd_' + alg for alg in algo_names]
    
    # Filter the DataFrame based on the algorithm names
    filter_df = input_df[input_df.index.isin(algo_names)].copy()
    
    # Sort algorithms by total time
    filter_df = filter_df.sort_values('TotalTime(ms)_mean')
    
    # Calculate total times and errors
    filter_df['TotalTime(ms)_mean'] = (filter_df['KeyGen(ms)_mean'] + 
                                 filter_df['Encaps(ms)_mean'] + 
                                 filter_df['Decaps(ms)_mean'])
    
    filter_df['TotalTime_std'] = np.sqrt(
        filter_df[f'KeyGen(ms){error_suffix}']**2 +
        filter_df[f'Encaps(ms){error_suffix}']**2 +
        filter_df[f'Decaps(ms){error_suffix}']**2
    )
    
    # Sort by total time
    filter_df = filter_df.sort_values('TotalTime(ms)_mean')
    
    # Create plot
    fig, ax = plt.subplots(figsize=(20, 10))
    
    # Set logarithmic scale if requested
    if log_scale:
        ax.set_yscale('log')
    
    algorithms = filter_df.index.tolist()  # algorithms are in the index
    x = np.arange(len(algorithms))  # label locations
    
    x = np.arange(len(filter_df.index))
    container = ax.bar(x, filter_df['TotalTime(ms)_mean'],
                      yerr=filter_df['TotalTime_std'],
                      capsize=3,
                      color="#33acdc",
                      edgecolor='black',
                      linewidth=1,
                      error_kw={'ecolor': 'black'},
                      zorder=3)
    
    # Apply consistent styling
    apply_axes_style(ax, 
                    xlabel='Algorithm',
                    ylabel='Time (ms)')
    
    # Set x-ticks with LaTeX formatting for underscores
    ax.set_xticks(x)
    ax.set_xticklabels([alg.replace('_', '\_') for alg in algorithms], 
                       rotation=45, 
                       horizontalalignment='right',
                       fontsize=FONT_SIZES['tick_label'])
    
    # Add grid with custom styling
    ax.grid(True, which='major', 
            alpha=AXES_STYLE['grid_alpha'], 
            zorder=0, 
            linewidth=AXES_STYLE['grid_linewidth'])
    ax.grid(True, which='minor', 
            color=AXES_STYLE['grid_color'],
            linestyle=AXES_STYLE['grid_linestyle'], 
            linewidth=AXES_STYLE['grid_linewidth'], 
            alpha=0.3)
    
    if y_start is not None:
        ax.set_ylim(y_start, None)
    
    plt.tight_layout()
    
    if not os.path.exists("./plots"):
        os.makedirs("./plots")
    
    plt.savefig(os.path.join(".", "plots", plot_title), 
                bbox_inches='tight', 
                dpi=300)
    plt.show()

def plot_kems_fast(input_df, error_suffix="_std", plot_title="fast_kems.png", y_start=None, y_end=None, log_scale=False):
    """
    Plots KEM timing measurements for fast algorithms (up to qkd_frodo976aes).
    
    Args:
        input_df: DataFrame containing the KEM timing data
        error_suffix: Suffix for error columns (default: "_std")
        plot_title: Output filename for the plot
        log_scale: Boolean to enable log scale on y-axis (default: False)
    """
    
    # Filter and sort algorithms
    cutoff_str = "frodo976aes"  # Common identifier for both datasets
    input_df = input_df.sort_values('TotalTime(ms)_mean')
    
    # Extract all algorithm names from KEM_FAMILIES
    algo_names = [alg for family in KEM_FAMILIES.values() for alg in family]

    # Check if the input_df index contains the 'qkd_' prefix
    has_qkd_prefix = any(idx.startswith('qkd_') for idx in input_df.index)
    
    # Add 'qkd_' prefix to algorithm names if necessary
    if has_qkd_prefix:
        algo_names = ['qkd_' + alg for alg in algo_names]
    
    # Find the cutoff index using string matching
    cutoff_idx = None
    for idx, alg in enumerate(input_df.index):
        if cutoff_str in alg:  # This will match both 'frodo976aes' and 'qkd_frodo976aes'
            cutoff_idx = idx + 1
            break
            
    if cutoff_idx is None:
        raise ValueError(f"Cutoff algorithm containing '{cutoff_str}' not found in dataset")
    
    
    fast_df_ = input_df.iloc[:cutoff_idx]
    
    # Filter the DataFrame based on the algorithm names
    fast_df = fast_df_[fast_df_.index.isin(algo_names)].copy()
    
    # Setup plot dimensions
    width = 0.25  # width of the bars
    algorithms = fast_df.index.tolist()
    x = np.arange(len(algorithms))
    
    # Create figure
    fig, ax = plt.subplots(figsize=(20, 10))
    
    if log_scale:
        ax.set_yscale('log')
    
    # Define colors and operations
    colors = list(mcolors.LinearSegmentedColormap.from_list("", ["#9fcf69", "#33acdc"])(np.linspace(0, 1, 3)))
    operations = ['KeyGen(ms)', 'Encaps(ms)', 'Decaps(ms)']
    
    # Plot bars for each operation
    bars = []
    for i, (operation, color) in enumerate(zip(operations, colors)):
        mean_col = f"{operation}_mean"
        std_col = f"{operation}{error_suffix}"
        
        container = ax.bar(x + (i-1)*width, 
                         fast_df[mean_col],
                         width,
                         label=operation.replace('(ms)', ''),
                         color=color,
                         edgecolor='black',
                         linewidth=1,
                         yerr=fast_df[std_col],
                         capsize=3,
                         error_kw={'ecolor': 'black'},
                         zorder=3)
        
        # Style error bars
        for line in container.errorbar.lines[2]:
            line.set_linestyle('dashed')
            line.set_linewidth(0.75)
        
        bars.append(container)
    
    # Apply consistent styling
    apply_axes_style(ax, 
                    xlabel='Algorithm',
                    ylabel='Time (ms)')
    
    # Set x-ticks with LaTeX formatting for underscores
    ax.set_xticks(x)
    ax.set_xticklabels([alg.replace('_', '\_') for alg in algorithms], 
                       rotation=45, 
                       horizontalalignment='right',
                       fontsize=FONT_SIZES['tick_label'])
    
    # Add grid with custom styling
    ax.grid(True, which='major', 
            alpha=AXES_STYLE['grid_alpha'], 
            zorder=0, 
            linewidth=AXES_STYLE['grid_linewidth'])
    ax.grid(True, which='minor', 
            color=AXES_STYLE['grid_color'],
            linestyle=AXES_STYLE['grid_linestyle'], 
            linewidth=AXES_STYLE['grid_linewidth'], 
            alpha=0.3)
    
    # Add legend below the title
    handles, labels = ax.get_legend_handles_labels()
    if labels:
        # Place legend below the plot title in a single row
        ax.legend(frameon=True, 
                 fontsize=FONT_SIZES['legend'],
                 loc='upper left',
                 bbox_to_anchor=(0, 1.01),
                 ncol=len(labels))
    
    # Add legend with consistent styling
    #ax.legend(loc='best',
    #         frameon=True, 
    #         fontsize=FONT_SIZES['legend'])
    
    # Set y-axis limits if specified
    if y_start or y_end is not None:
        ax.set_ylim(y_start, y_end)
    
    plt.tight_layout()
    
    # Save plot
    if not os.path.exists("./plots"):
        os.makedirs("./plots")
    
    plt.savefig(os.path.join(".", "plots", plot_title), bbox_inches='tight', dpi=300)
    plt.show()
    
def plot_kem_family(input_df, family, error_suffix="_std", plot_title=None, log_scale=False):
    """
    Plots KEM timing measurements for a specific family of algorithms.
    
    Args:
        input_df: DataFrame containing the KEM timing data
        family: String indicating which family to plot ('kyber', 'mlkem', 'bike', 'frodo', 'hqc')
        error_suffix: Suffix for error columns (default: "_std")
        plot_title: Output filename for the plot (default: family_kems.png)
        log_scale: Boolean to enable log scale on y-axis (default: False)
    """
    # Validate family selection
    family = family.lower()
    if family not in KEM_FAMILIES:
        raise ValueError(f"Unknown family '{family}'. Available families: {list(KEM_FAMILIES.keys())}")
    
    # Determine if we're dealing with QKD or standard algorithms
    is_qkd = any('qkd_' in alg for alg in input_df.index)
    
    # Get base algorithms and add prefix if needed
    base_algs = KEM_FAMILIES[family]
    family_algs = [f'qkd_{alg}' if is_qkd else alg for alg in base_algs]
    
    # Filter existing algorithms and create DataFrame
    family_df = input_df.loc[family_algs].sort_values('TotalTime(ms)_mean')
    
    # Setup plot dimensions
    width = 0.25  # width of the bars
    algorithms = family_df.index.tolist()
    x = np.arange(len(algorithms))
    
    # Create figure
    fig, ax = plt.subplots(figsize=(20, 10))
    
    if log_scale:
        ax.set_yscale('log')
    
    # Define colors and operations
    colors = list(mcolors.LinearSegmentedColormap.from_list("", ["#9fcf69", "#33acdc"])(np.linspace(0, 1, 3)))
    operations = ['KeyGen(ms)', 'Encaps(ms)', 'Decaps(ms)']
    
    # Plot bars for each operation
    for i, (operation, color) in enumerate(zip(operations, colors)):
        mean_col = f"{operation}_mean"
        std_col = f"{operation}{error_suffix}"
        
        container = ax.bar(x + (i-1)*width, 
                         family_df[mean_col],
                         width,
                         label=operation.replace('(ms)', ''),
                         color=color,
                         edgecolor='black',
                         linewidth=1,
                         yerr=family_df[std_col],
                         capsize=3,
                         error_kw={'ecolor': 'black'},
                         zorder=3)
        
        # Style error bars
        for line in container.errorbar.lines[2]:
            line.set_linestyle('dashed')
            line.set_linewidth(0.75)
    
    # Apply consistent styling
    apply_axes_style(ax, 
                    xlabel='Algorithm',
                    ylabel='Time (ms)')
    
    # Set x-ticks with LaTeX formatting for underscores
    ax.set_xticks(x)
    ax.set_xticklabels([alg.replace('_', '\_') for alg in algorithms], 
                       rotation=45, 
                       horizontalalignment='right',
                       fontsize=FONT_SIZES['tick_label'])
    
    # Add grid with custom styling
    ax.grid(True, which='major', 
            alpha=AXES_STYLE['grid_alpha'], 
            zorder=0, 
            linewidth=AXES_STYLE['grid_linewidth'])
    ax.grid(True, which='minor', 
            color=AXES_STYLE['grid_color'],
            linestyle=AXES_STYLE['grid_linestyle'], 
            linewidth=AXES_STYLE['grid_linewidth'], 
            alpha=0.3)
    
    # Ensure some padding above the highest bar
    ax.margins(y=0.1)
    
    # Add legend below the title
    handles, labels = ax.get_legend_handles_labels()
    if labels:
        # Place legend below the plot title in a single row
        ax.legend(frameon=False, 
                 fontsize=FONT_SIZES['legend'],
                 loc='upper center',
                 bbox_to_anchor=(0.5, 1.01),
                 ncol=len(labels))
    
    # Set title
    ax.set_title(f'{family.upper()} Family', fontsize=FONT_SIZES['fig_title'], pad=20)
    
    plt.tight_layout()
    
    # Save plot
    if not os.path.exists("./plots"):
        os.makedirs("./plots")
    
    if plot_title is None:
        plot_title = f"{family}_kems.pdf"
    
    plt.savefig(os.path.join(".", "plots", plot_title), 
                bbox_inches='tight', 
                dpi=300)
    plt.show()
    
def plot_ops_percent(input_df, family=None, plot_title="operation_percentages.png", print_percents=False):
    """
    Creates a stacked bar plot showing the percentage contribution of each operation.
    
    Args:
        input_df: DataFrame containing the KEM timing data
        family: Optional string to filter for specific algorithm family
        plot_title: Output filename for the plot
        print_percents: Boolean to control printing of numerical percentages (default: False)
    """
    # Determine if we're dealing with QKD or standard algorithms
    is_qkd = any('qkd_' in alg for alg in input_df.index)
    # Function to add prefix to algorithm names
    def add_prefix(algs):
        return [f'qkd_{alg}' if is_qkd else alg for alg in algs]
    
    # Filter and sort data
    if family is not None:
        if family.lower() not in KEM_FAMILIES:
            raise ValueError(f"Unknown family '{family}'. Available families: {list(KEM_FAMILIES.keys())}")
        base_algs = KEM_FAMILIES[family.lower()]
        family_algs = add_prefix(base_algs)
        df_to_plot = input_df.loc[family_algs]
        df_to_plot = df_to_plot.sort_values('TotalTime(ms)_mean')
    else:
        # Group by families when plotting all algorithms
        df_to_plot = pd.DataFrame()
        for fam in KEM_FAMILIES:
            base_algs = KEM_FAMILIES[fam]
            family_algs = add_prefix(base_algs)
            family_data = input_df.loc[family_algs].sort_values('TotalTime(ms)_mean')
            df_to_plot = pd.concat([df_to_plot, family_data])

    # Calculate percentages
    percentages = compute_ops_percent(df_to_plot)
    
    # Setup plot dimensions
    fig, ax = plt.subplots(figsize=(20, 10))
    
    # Setup plot dimensions
    algorithms = percentages.index.tolist()  # algorithms are in the index
    x = np.arange(len(algorithms))  # label locations
    
    # Get x-axis positions
    x = np.arange(len(percentages.index))
    
    # Colors for the three operations with slight transparency
    colors = list(mcolors.LinearSegmentedColormap.from_list("", ["#9fcf69", "#33acdc"])(np.linspace(0, 1, 3)))
    colors = [mcolors.to_rgba(c, alpha=0.85) for c in colors]  # Add slight transparency
    
    # Create stacked bars
    bottom = np.zeros(len(percentages.index))
    bars = []
    labels = ['KeyGen', 'Encaps', 'Decaps']
    
    for (col, color, label) in zip(['KeyGen(ms)_mean', 'Encaps(ms)_mean', 'Decaps(ms)_mean'], 
                                 colors, labels):
        bars.append(ax.bar(x, percentages[col], bottom=bottom, label=label,
                         color=color, edgecolor='black', linewidth=1))
        bottom += percentages[col]
    
    # Add percentage labels on the bars
    for bars_group in bars:
        for bar in bars_group:
            height = bar.get_height()
            if height > 5:  # Only show label if percentage > 5%
                ax.text(bar.get_x() + bar.get_width()/2., 
                       bar.get_y() + height/2.,
                       f'{height:.1f}\%',
                       ha='center', va='center', rotation=0,
                       fontsize=14)
    
    # Apply consistent styling
    apply_axes_style(ax, 
                    xlabel=r'Algorithm',
                    ylabel=r'Percentage of Total Time (\%)')
    
    # Set x-ticks with LaTeX formatting for underscores
    ax.set_xticks(x)
    ax.set_xticklabels([alg.replace('_', '\_') for alg in algorithms], 
                       rotation=45, 
                       horizontalalignment='right',
                       fontsize=FONT_SIZES['tick_label'])
    
    ax.set_ylim(0, 100)
    ax.set_xlim(-0.5, len(algorithms) - 0.5)
    
    # Set major and minor tick locators
    ax.yaxis.set_major_locator(MultipleLocator(10))  # Major ticks every 2 units
    ax.yaxis.set_minor_locator(AutoMinorLocator())  # Minor ticks between majors
    
    # Add grid with custom styling
    ax.grid(True, which='major', 
            alpha=AXES_STYLE['grid_alpha'], 
            zorder=0, 
            linewidth=AXES_STYLE['grid_linewidth'])
    ax.grid(True, which='minor', 
            color=AXES_STYLE['grid_color'],
            linestyle=AXES_STYLE['grid_linestyle'], 
            linewidth=AXES_STYLE['grid_linewidth'], 
            alpha=0.3)
    
    # Add legend below the title
    handles, labels = ax.get_legend_handles_labels()
    if labels:
        ax.legend(frameon=False, 
                fontsize=FONT_SIZES['legend'],
                loc='upper center',
                bbox_to_anchor=(0.5, 1.1),
                ncol=len(labels))

    # Add title if showing a specific family
    if family is not None:
        prefix = "QKD-" if is_qkd else ""
        ax.set_title(f'{prefix}{family.upper()} Family', fontsize=FONT_SIZES['fig_title'], pad=20)
    
    # Add family separators when plotting all algorithms
    if family is None:
        prev_family = None
        for i, alg in enumerate(percentages.index):
            # Remove qkd_ prefix for family lookup if present
            base_alg = alg.replace('qkd_', '') if is_qkd else alg
            current_family = next(fam for fam, algs in KEM_FAMILIES.items() 
                                if any(base_alg.startswith(a) for a in algs))
            if prev_family != current_family and i > 0:
                ax.axvline(x=i-0.5, color='black', linestyle='--', alpha=0.3, linewidth=1)
            prev_family = current_family
    
    plt.tight_layout()
    
    # Save plot
    if not os.path.exists("./plots"):
        os.makedirs("./plots")
    
    plt.savefig(os.path.join(".", "plots", plot_title), 
                bbox_inches='tight', 
                dpi=300)
    plt.show()

    if print_percents:
        # Print numerical percentages
        print("\nOperation Percentages:")
        print(percentages.round(2))
    
def plot_kem_comparison(comparison_stats, family=None, operation='TotalTime(ms)', 
                       overhead=False, log_scale=False, plot_title=None):
    """
    Creates a comparative plot of standard vs QKD versions of KEMs, adding std dev error bars.
    """
    # Validate family selection
    if family is not None and family not in KEM_FAMILIES:
        raise ValueError(f"Unknown family '{family}'. Available families: {list(KEM_FAMILIES.keys())}")
    
    families_to_plot = [family] if family else KEM_FAMILIES.keys()
    operations = ['KeyGen(ms)', 'Encaps(ms)', 'Decaps(ms)']
    
    operation_labels = {
        'standard': {
            'KeyGen(ms)': r'\textbf{Key Generation Time (ms)}',
            'Encaps(ms)': r'\textbf{Encapsulation Time (ms)}',
            'Decaps(ms)': r'\textbf{Decapsulation Time (ms)}',
            'TotalTime(ms)': r'\textbf{Time (ms)}',
            'all': r'\textbf{Total Time (ms)}'
        },
        'overhead': {
            'KeyGen(ms)': r'\textbf{Key Generation Overhead (\%)}',
            'Encaps(ms)': r'\textbf{Encapsulation Overhead (\%)}',
            'Decaps(ms)': r'\textbf{Decapsulation Overhead (\%)}',
            'TotalTime(ms)': r'\textbf{Total Time Overhead (\%)}',
            'all': r'\textbf{Time Overhead (\%)}'
        }
    }
    
    fig, ax = plt.subplots(figsize=(20, 10))
    
    # Set colors
    colors = list(mcolors.LinearSegmentedColormap.from_list("",
        ["#9fcf69", "#33acdc", "#ff7f50"])(np.linspace(0, 1, 3)))
    colors = [mcolors.to_rgba(c, alpha=0.85) for c in colors]
    
    # Configure axis style
    ax.grid(AXES_STYLE['grid'], alpha=AXES_STYLE['grid_alpha'],
            linestyle=AXES_STYLE['grid_linestyle'],
            linewidth=AXES_STYLE['grid_linewidth'],
            color=AXES_STYLE['grid_color'])
    ax.tick_params(which='major', length=AXES_STYLE['major_tick_length'],
                   width=AXES_STYLE['major_tick_width'])
    ax.tick_params(which='minor', length=AXES_STYLE['minor_tick_length'],
                   width=AXES_STYLE['minor_tick_width'])
    
    if operation == 'all':
        x_positions = []
        x_labels = []
        current_x = 0
        width = 0.15
        std_color = "#9fcf69"
        qkd_color = "#33acdc"
        
        for fam in families_to_plot:
            base_algs = KEM_FAMILIES[fam]
            for base_alg in base_algs:
                for i, op in enumerate(operations):
                    # Mean values
                    std_val = comparison_stats.loc[('OQS', base_alg), f"{op}_mean"]
                    qkd_val = comparison_stats.loc[('QKD', base_alg), f"{op}_mean"]
                    # Standard deviations
                    std_err = comparison_stats.loc[('OQS', base_alg), f"{op}_std"]
                    qkd_err = comparison_stats.loc[('QKD', base_alg), f"{op}_std"]
                    x_offset = i * (3 * width)
                    
                    # Plot with error bars
                    ax.bar(current_x + x_offset,
                           std_val,
                           width,
                           yerr=std_err,
                           capsize=3,
                           label='OQS' if (current_x == 0 and i == 0) else "",
                           color=std_color,
                           edgecolor='black',
                           linewidth=1,
                           error_kw={'ecolor': 'black'})
                    ax.bar(current_x + x_offset + width,
                           qkd_val,
                           width,
                           yerr=qkd_err,
                           capsize=3,
                           label='QKD' if (current_x == 0 and i == 0) else "",
                           color=qkd_color,
                           edgecolor='black',
                           linewidth=1,
                           error_kw={'ecolor': 'black'})
                    
                    # Operation label above first group
                    if current_x == 0:
                        op_label = op.split('(')[0]
                        ax.text(current_x + x_offset + width/2,
                                ax.get_ylim()[1],
                                op_label,
                                ha='center',
                                va='bottom',
                                fontsize=FONT_SIZES['annotation'])
                
                x_positions.append(current_x + 3*width)
                x_labels.append(base_alg.replace('_','\_'))
                current_x += 10*width
            
            # Separator between families
            if not family and fam != list(families_to_plot)[-1]:
                ax.axvline(x=current_x - 3*width, color='black',
                           linestyle='--', alpha=0.3, linewidth=1)
                current_x += 2*width
        
        ax.set_xticks(x_positions)
        ax.set_xticklabels(x_labels, rotation=45, ha='right', fontsize=FONT_SIZES['tick_label'])
        
    else:
        std_data = []
        qkd_data = []
        std_errs = []
        qkd_errs = []
        labels = []
        
        for fam in families_to_plot:
            base_algs = KEM_FAMILIES[fam]
            op_col = f"{operation}_mean"
            err_col = f"{operation}_std"
            for base_alg in base_algs:
                std_data.append(comparison_stats.loc[('OQS', base_alg), op_col])
                qkd_data.append(comparison_stats.loc[('QKD', base_alg), op_col])
                std_errs.append(comparison_stats.loc[('OQS', base_alg), err_col])
                qkd_errs.append(comparison_stats.loc[('QKD', base_alg), err_col])
                labels.append(base_alg)
        
        x = np.arange(len(labels))
        width = 0.35
        
        if overhead:
            # Overhead computation - no direct error bars for the overhead
            overhead_data = [((q - s) / s) * 100 for s, q in zip(std_data, qkd_data)]
            ax.bar(x,
                   overhead_data,
                   width,
                   color=colors[0],
                   edgecolor='black',
                   linewidth=1)
            for i, v in enumerate(overhead_data):
                ax.text(i, v, f'{v:.1f}\%', ha='center', va='bottom',
                        fontsize=FONT_SIZES['annotation'])
        else:
            # Plot OQS with error
            ax.bar(x - width/2,
                   std_data,
                   width,
                   yerr=std_errs,
                   capsize=3,
                   label='OQS',
                   color=colors[0],
                   edgecolor='black',
                   linewidth=1,
                   error_kw={'ecolor': 'black'})
            # Plot QKD with error
            ax.bar(x + width/2,
                   qkd_data,
                   width,
                   yerr=qkd_errs,
                   capsize=3,
                   label='QKD',
                   color=colors[1],
                   edgecolor='black',
                   linewidth=1,
                   error_kw={'ecolor': 'black'})
            
        ax.set_xticks(x)
        ax.set_xticklabels([label.replace('_','\_') for label in labels], 
                           rotation=45, ha='right', fontsize=FONT_SIZES['tick_label'])
    
    label_type = 'overhead' if overhead else 'standard'
    ylabel = operation_labels[label_type].get(operation, operation_labels[label_type]['all'])
    ax.set_ylabel(ylabel,
                  fontsize=FONT_SIZES['axes_label'],
                  labelpad=AXES_STYLE['label_pad'])
    ax.set_xlabel(r'\textbf{Algorithm}',
                  fontsize=FONT_SIZES['axes_label'],
                  labelpad=AXES_STYLE['label_pad'])
    ax.yaxis.set_minor_locator(AutoMinorLocator())
    
    handles, labels = ax.get_legend_handles_labels()
    if labels:
        ax.legend(frameon=False, fontsize=FONT_SIZES['legend'])
    
    if family:
        ax.set_title(f'{family.upper()} Family', fontsize=FONT_SIZES['axes_title'], pad=20)
    
    plt.tight_layout()
    
    if plot_title:
        if not os.path.exists("./plots"):
            os.makedirs("./plots")
        plt.savefig(os.path.join(".", "plots", plot_title), 
                    bbox_inches='tight', dpi=300)
    
    plt.show()
    
def plot_tls_kem_families(input_df, cert_type='rsa_2048', plot_title=None):
    """
    Plots TLS handshake times for different KEM families using a specific certificate.
    Handles both single provider data and OQS vs QKD comparison with hierarchical index.
    
    Args:
        input_df: DataFrame with TLS benchmark data processed by tls_data_process()
           Can be single provider data or merged data with Provider level index
        cert_type: Which certificate to analyze ('rsa_2048', 'falcon512', etc.)
        plot_title: Optional filename for saving plot
    """
    # Check if we have merged data by looking at index levels
    is_comparison = 'Provider' in input_df.index.names
    
    if is_comparison:
        # For merged data, filter certificate and get both variants
        oqs_data = input_df.xs(('OQS', cert_type), level=('Provider', 'Cert'))
        qkd_data = input_df.xs(('QKD', cert_type), level=('Provider', 'Cert'))
    else:
        # Original single provider data handling
        family_data = input_df.xs(cert_type, level='Cert')
    
    # Create ordered list of KEMs based on KEM_FAMILIES
    ordered_kems = []
    for family, algs in KEM_FAMILIES.items():
        ordered_kems.extend(algs)
    
    # Create figure
    fig, ax = plt.subplots(figsize=(20, 10))
    
    # Get x positions
    x = np.arange(len(ordered_kems))
    
   # Set colors
    colors = list(mcolors.LinearSegmentedColormap.from_list("", 
        ["#9fcf69", "#33acdc", "#ff7f50"])(np.linspace(0, 1, 3)))
    colors = [mcolors.to_rgba(c, alpha=0.85) for c in colors]
    
    if is_comparison:
        # Plot comparison (OQS vs QKD)
        width = 0.35
        
        # Plot OQS bars
        rects1 = ax.bar(x - width/2, 
                       [oqs_data.loc[kem]['Time_mean'] for kem in ordered_kems],
                       width, label='OQS',
                       yerr=[oqs_data.loc[kem]['Time_std'] for kem in ordered_kems],
                       capsize=3,
                       color=colors[0],
                       edgecolor='black',
                       linewidth=1,
                       error_kw={'ecolor': 'black'},
                       zorder=3)
        
        # Plot QKD bars
        rects2 = ax.bar(x + width/2, 
                       [qkd_data.loc[f"qkd_{kem}"]['Time_mean'] for kem in ordered_kems],
                       width, label='QKD-KEM',
                       yerr=[qkd_data.loc[f"qkd_{kem}"]['Time_std'] for kem in ordered_kems],
                       capsize=3,
                       color=colors[1],
                       edgecolor='black',
                       linewidth=1,
                       error_kw={'ecolor': 'black'},
                       zorder=3)
        
        # Add legend
        ax.legend(frameon=True, fontsize=FONT_SIZES['legend'])
        
    else:
        # Original single provider plotting
        width = 0.35
        rects = ax.bar(x, family_data['Time_mean'], width,
                      yerr=family_data['Time_std'],
                      capsize=3,
                      color=colors[1],
                      edgecolor='black',
                      linewidth=1,
                      error_kw={'ecolor': 'black'},
                      zorder=3)
    
    # Apply consistent styling
    apply_axes_style(ax, 
                    xlabel=r'\textbf{Algorithm}',
                    ylabel=r'\textbf{Handshake Time (ms)}')
    
    # Set x-ticks with LaTeX formatting for underscores
    ax.set_xticks(x)
    ax.set_xticklabels([kem.replace('_', '\_') for kem in ordered_kems], 
                       rotation=45, 
                       horizontalalignment='right',
                       fontsize=FONT_SIZES['tick_label'])
    
    # Add grid with custom styling
    ax.grid(True, which='major', 
            alpha=AXES_STYLE['grid_alpha'], 
            zorder=0, 
            linewidth=AXES_STYLE['grid_linewidth'])
    ax.grid(True, which='minor', 
            color=AXES_STYLE['grid_color'],
            linestyle=AXES_STYLE['grid_linestyle'], 
            linewidth=AXES_STYLE['grid_linewidth'], 
            alpha=0.3)
    
    # Add minor ticks
    ax.yaxis.set_minor_locator(AutoMinorLocator())
    
    # Add title specifying certificate type
    ax.set_title(f'Using {cert_type} Signatures', 
                fontsize=FONT_SIZES['fig_title'], 
                pad=20)
    
    plt.tight_layout()
    
    # Save plot if title provided
    if plot_title:
        if not os.path.exists("./plots"):
            os.makedirs("./plots")
        plt.savefig(os.path.join(".", "plots", plot_title), 
                    bbox_inches='tight', 
                    dpi=300)
    
    plt.show()
    
    
def plot_tls_certs_families(input_df, kem_type='mlkem512', plot_title=None):
    """
    Plots TLS handshake times showing the impact of different certificates 
    on a specific KEM variant.
    
    Args:
        input_df: DataFrame with TLS benchmark data processed by tls_data_process()
        kem_type: Which KEM variant to analyze (e.g., 'mlkem512', 'bikel1', etc.)
        plot_title: Optional filename for saving plot
    """
    # Check if we're dealing with QKD KEMs
    is_qkd = any('qkd_' in idx[0] for idx in input_df.index)
    prefix = 'qkd_' if is_qkd else ''
    kem_name = f"{prefix}{kem_type}"
    
    # Get data for this KEM
    try:
        kem_data = input_df.loc[kem_name]
    except KeyError:
        raise ValueError(f"KEM variant '{kem_type}' not found in data")
    
    # Define certificate order by security level
    cert_order = [
        # Classical RSA
        'rsa_2048', 'rsa_3072', 'rsa_4096',
        # MLDSA
        'mldsa44', 'mldsa65', 'mldsa87',
        # Falcon
        'falcon512', 'falcon1024',
        # SPHINCS+
        #'sphincssha2128fsimple', 'sphincssha2128ssimple', 
        #'sphincssha2192fsimple', 'sphincsshake128fsimple'
    ]
    
    # Sort the data according to our ordered list
    kem_data = kem_data.reindex(cert_order)
    
    # Create figure
    fig, ax = plt.subplots(figsize=(20, 10))
    
    # Get x positions and labels
    x = np.arange(len(kem_data))
    
    # Set colors
    colors = list(mcolors.LinearSegmentedColormap.from_list("", 
        ["#9fcf69", "#33acdc", "#ff7f50"])(np.linspace(0, 1, 3)))
    colors = [mcolors.to_rgba(c, alpha=0.85) for c in colors]
    
    # Create bars
    width = 0.35
    rects = ax.bar(x, kem_data['Time_mean'], width,
                  yerr=kem_data['Time_std'],
                  capsize=3,
                  color=colors[1],
                  edgecolor='black',
                  linewidth=1,
                  error_kw={'ecolor': 'black'},
                  zorder=3)
    
    # Apply consistent styling
    apply_axes_style(ax, 
                    xlabel=r'\textbf{Certificate}',
                    ylabel=r'\textbf{TLS Handshake Time (ms)}')
    
    # Set x-ticks with LaTeX formatting for underscores
    ax.set_xticks(x)
    ax.set_xticklabels([cert.replace('_', '\_') for cert in cert_order], 
                       rotation=45, 
                       horizontalalignment='right',
                       fontsize=FONT_SIZES['tick_label'])
    
    # Add grid with custom styling
    ax.grid(True, which='major', 
            alpha=AXES_STYLE['grid_alpha'], 
            zorder=0, 
            linewidth=AXES_STYLE['grid_linewidth'])
    ax.grid(True, which='minor', 
            color=AXES_STYLE['grid_color'],
            linestyle=AXES_STYLE['grid_linestyle'], 
            linewidth=AXES_STYLE['grid_linewidth'], 
            alpha=0.3)
    
    # Add minor ticks
    ax.yaxis.set_minor_locator(AutoMinorLocator())
    
    # Add title specifying KEM type
    ax.set_title(f'{kem_name}', 
                fontsize=FONT_SIZES['fig_title'], 
                pad=20)
    
    plt.tight_layout()
    
    # Save plot if title provided
    if plot_title:
        if not os.path.exists("./plots"):
            os.makedirs("./plots")
        plt.savefig(os.path.join(".", "plots", plot_title), 
                    bbox_inches='tight', 
                    dpi=300)
    
    plt.show()


