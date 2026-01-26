#!/usr/bin/env python3
"""
Analyze timing data from PHOLD benchmark experiments.

Extracts timing information from generated files and creates comparison plots.
"""

import os
import json
import re
from pathlib import Path
from collections import defaultdict
import numpy as np
import matplotlib.pyplot as plt

# Configuration
OUTPUT_DIR = Path("output")


def parse_directory_name(dirname):
    """Extract parameters from directory name.
    
    Format: height-{h}_width-{w}_numRings-{r}_numNodes-{n}_numRanks-{rk}
    """
    pattern = r'height-(\d+)_width-(\d+)_numRings-(\d+)_numNodes-(\d+)_numRanks-(\d+)'
    match = re.match(pattern, dirname)
    if match:
        return {
            'height': int(match.group(1)),
            'width': int(match.group(2)),
            'numRings': int(match.group(3)),
            'numNodes': int(match.group(4)),
            'numRanks': int(match.group(5)),
        }
    return None


def extract_real_time(filepath):
    """Extract 'real' time from timing file."""
    try:
        with open(filepath, 'r') as f:
            content = f.read()
            # Look for pattern like "real	0m1.234s"
            match = re.search(r'real\s+(\d+)m([\d.]+)s', content)
            if match:
                minutes = int(match.group(1))
                seconds = float(match.group(2))
                return minutes * 60 + seconds
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
    return None


def extract_elapsed_time(filepath):
    """Extract 'Elapsed time' from elapsed file."""
    try:
        with open(filepath, 'r') as f:
            content = f.read()
            # Look for pattern like "Elapsed time (s): 123.456"
            match = re.search(r'Elapsed time \(s\):\s*([\d.]+)', content)
            if match:
                return float(match.group(1))
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
    return None


def extract_max_build_time(filepath):
    """Extract 'max_build_time' from JSON timing file."""
    try:
        with open(filepath, 'r') as f:
            data = json.load(f)
            # max_build_time is nested under 'timing-info'
            if 'timing-info' in data and 'max_build_time' in data['timing-info']:
                return data['timing-info']['max_build_time']
            elif 'max_build_time' in data:
                return data['max_build_time']
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
    return None


def collect_timing_data():
    """Collect all timing data from output directory."""
    data = defaultdict(lambda: defaultdict(list))
    
    for subdir in sorted(OUTPUT_DIR.iterdir()):
        if not subdir.is_dir():
            continue
        
        dirname = subdir.name
        params = parse_directory_name(dirname)
        if not params:
            continue
        
        config_key = (params['height'], params['width'], params['numRings'], 
                      params['numNodes'], params['numRanks'])
        
        # Collect generation timings
        gen_mpi_files = list(subdir.glob('gen_mpi_time_trial_*.txt'))
        gen_py_files = list(subdir.glob('gen_py_trial_*_elapsed.txt'))
        
        for f in gen_mpi_files:
            trial_num = re.search(r'trial_(\d+)', f.name)
            if trial_num:
                t = extract_real_time(f)
                if t is not None:
                    data[config_key]['gen_mpi'].append(t)
        
        for f in gen_py_files:
            trial_num = re.search(r'trial_(\d+)', f.name)
            if trial_num:
                t = extract_elapsed_time(f)
                if t is not None:
                    data[config_key]['gen_py'].append(t)
        
        # Collect build timings
        sim_mpi_files = list(subdir.glob('sim_mpi_timing_trial_*.json'))
        sim_py_files = list(subdir.glob('sim_py_timing_trial_*.json'))
        
        for f in sim_mpi_files:
            t = extract_max_build_time(f)
            if t is not None:
                data[config_key]['build_mpi'].append(t)
            else:
                print(f"  Warning: Could not extract max_build_time from {f.name}")
        
        for f in sim_py_files:
            t = extract_max_build_time(f)
            if t is not None:
                data[config_key]['build_py'].append(t)
            else:
                print(f"  Warning: Could not extract max_build_time from {f.name}")
    
    return data


def compute_statistics(data):
    """Compute mean, min, and max for each configuration."""
    stats = {}
    for config, timings in data.items():
        stats[config] = {}
        for key, values in timings.items():
            if values:
                stats[config][key] = {
                    'mean': np.mean(values),
                    'min': np.min(values),
                    'max': np.max(values),
                    'values': values,
                }
    return stats


def organize_by_height_width(stats):
    """Organize data by height×width pairs, with x-axis as numRanks * numNodes (total ranks)."""
    organized = defaultdict(lambda: defaultdict(lambda: defaultdict(list)))
    
    for config, timing_stats in stats.items():
        height = config[0]
        width = config[1]
        numNodes = config[3]
        numRanks = config[4]
        total_ranks = numRanks * numNodes
        
        size_key = (height, width)
        
        for timing_type, stat in timing_stats.items():
            organized[size_key][timing_type][numNodes].append({
                'total_ranks': total_ranks,
                'mean': stat['mean'],
                'min': stat['min'],
                'max': stat['max'],
            })
    
    return organized


def plot_generation_timings(stats):
    """Create comparison plots for generation timings for each height×width configuration."""
    organized = organize_by_height_width(stats)
    
    # Node markers (same for both With SST and Without SST)
    node_markers = {
        4: 'o',   # circles
        8: 's',   # squares
        16: '^',  # triangles
    }
    
    # Colors for With SST (blue) and Without SST (orange)
    sst_color = 'blue'
    no_sst_color = 'orange'
    
    # Get all height×width configurations
    size_keys = sorted(organized.keys())
    
    if not size_keys:
        print("No data found")
        return
    
    # Organize by height (rows) and width (columns)
    heights = sorted(set(h for h, w in size_keys))
    widths = sorted(set(w for h, w in size_keys))
    
    n_rows = len(heights)
    n_cols = len(widths)
    
    # Create figure with subplots: rows=heights, cols=widths
    fig, axes = plt.subplots(n_rows, n_cols, figsize=(5 * n_cols, 4 * n_rows))
    
    # Handle case where there's only one row or one column
    if n_rows == 1 and n_cols == 1:
        axes = np.array([[axes]])
    elif n_rows == 1:
        axes = axes.reshape(1, -1)
    elif n_cols == 1:
        axes = axes.reshape(-1, 1)
    
    # Track handles and labels for shared legend
    all_handles = []
    all_labels = []
    first_plot = True
    
    for row_idx, height in enumerate(heights):
        for col_idx, width in enumerate(widths):
            ax = axes[row_idx, col_idx]
            
            if (height, width) not in organized:
                ax.set_visible(False)
                continue
            
            timing_data = organized[(height, width)]
            
            # Collect all x values for tick marks
            all_x_vals = set()
            
            # Store data for computing differences
            mpi_data = {}  # {(numNodes, total_ranks): max_value}
            py_data = {}   # {(numNodes, total_ranks): max_value}
            
            # Plot With SST (gen_mpi) in blue
            if 'gen_mpi' in timing_data:
                node_data = timing_data['gen_mpi']
                for numNodes in sorted(node_data.keys()):
                    if numNodes not in node_markers:
                        continue
                    
                    marker = node_markers[numNodes]
                    points = sorted(node_data[numNodes], key=lambda p: p['total_ranks'])
                    
                    x_vals = [p['total_ranks'] for p in points]
                    maxes = [p['max'] for p in points]
                    
                    # Store for difference calculation
                    for x, m in zip(x_vals, maxes):
                        mpi_data[(numNodes, x)] = m
                    
                    all_x_vals.update(x_vals)
                    
                    scatter = ax.scatter(x_vals, maxes, marker=marker, color=sst_color, 
                              label=f'With SST ({numNodes} Nodes)', s=80)
                    
                    # Only collect legend entries from first subplot
                    if first_plot:
                        all_handles.append(scatter)
                        all_labels.append(f'With SST ({numNodes} Nodes)')
            
            # Plot Without SST (gen_py) in orange
            if 'gen_py' in timing_data:
                node_data = timing_data['gen_py']
                for numNodes in sorted(node_data.keys()):
                    if numNodes not in node_markers:
                        continue
                    
                    marker = node_markers[numNodes]
                    points = sorted(node_data[numNodes], key=lambda p: p['total_ranks'])
                    
                    x_vals = [p['total_ranks'] for p in points]
                    maxes = [p['max'] for p in points]
                    
                    # Store for difference calculation
                    for x, m in zip(x_vals, maxes):
                        py_data[(numNodes, x)] = m
                    
                    all_x_vals.update(x_vals)
                    
                    scatter = ax.scatter(x_vals, maxes, marker=marker, color=no_sst_color, 
                              label=f'Without SST ({numNodes} Nodes)', s=80)
                    
                    # Only collect legend entries from first subplot
                    if first_plot:
                        all_handles.append(scatter)
                        all_labels.append(f'Without SST ({numNodes} Nodes)')
            
            # Add difference annotations between MPI and Python points
            for key in mpi_data:
                if key in py_data:
                    numNodes, total_ranks = key
                    mpi_val = mpi_data[key]
                    py_val = py_data[key]
                    diff = abs(py_val - mpi_val)
                    
                    # Position text between the two points (geometric mean for log scale)
                    y_pos = np.sqrt(mpi_val * py_val)
                    
                    diff_text = f'{diff:.1f}'
                    
                    ax.annotate(diff_text, (total_ranks, y_pos), 
                               fontsize=7, ha='center', va='center',
                               color='black', fontweight='bold')
            
            first_plot = False
            
            ax.set_title(f'{height}x{width}')
            ax.set_xscale('log', base=2)
            ax.set_yscale('log', base=10)
            
            # Set x-axis ticks to powers of 2
            if all_x_vals:
                x_ticks = sorted(all_x_vals)
                ax.set_xticks(x_ticks)
                ax.set_xticklabels([str(int(x)) for x in x_ticks])
            
            ax.grid(True, alpha=0.3, which='both')
            
            # Only set y-axis label on the first (left) column
            if col_idx == 0:
                ax.set_ylabel('Time (seconds)')
            
            # Only set x-axis label on the last (bottom) row
            if row_idx == n_rows - 1:
                ax.set_xlabel('Total Ranks')
    
    # Add overarching title
    fig.suptitle('PHOLD JSON Dump Timings (Log₂ x-axis, Log₁₀ y-axis)', fontsize=14, y=0.98)
    
    # Add shared legend at the bottom
    fig.legend(all_handles, all_labels, loc='lower center', ncol=len(all_labels), 
               bbox_to_anchor=(0.5, -0.02), frameon=True)
    
    plt.tight_layout(rect=[0, 0.05, 1, 0.96])
    plt.savefig('generation_timings_combined.png', dpi=300, bbox_inches='tight')
    print(f"Saved: generation_timings_combined.png")
    plt.close()


def print_summary(stats):
    """Print a summary of collected data."""
    print("\n" + "="*80)
    print("TIMING DATA SUMMARY")
    print("="*80)
    
    for config in sorted(stats.keys()):
        params = {
            'height': config[0],
            'width': config[1],
            'numRings': config[2],
            'numNodes': config[3],
            'numRanks': config[4],
        }
        print(f"\nConfiguration: {params}")
        
        for timing_type, stat in sorted(stats[config].items()):
            mean_val = stat['mean']
            min_val = stat['min']
            max_val = stat['max']
            n_trials = len(stat['values'])
            print(f"  {timing_type:12s}: {mean_val:8.3f} s (min: {min_val:.3f}, max: {max_val:.3f}) ({n_trials} trials)")


def main():
    print("Collecting timing data...")
    data = collect_timing_data()
    
    if not data:
        print("No timing data found in output directory!")
        return
    
    print(f"Found {len(data)} configurations")
    
    stats = compute_statistics(data)
    
    print_summary(stats)
    
    print("\nGenerating figures...")
    plot_generation_timings(stats)
    
    print("\nDone!")


if __name__ == '__main__':
    main()
