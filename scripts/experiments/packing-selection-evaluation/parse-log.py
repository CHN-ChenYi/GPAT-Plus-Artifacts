#!/usr/bin/env python3
# Parse output logs of packing selection evaluation

import argparse
import matplotlib.pyplot as plt
import sys
import scipy.stats as st
from math import sqrt
from pathlib import Path

# parse google benchmark results
def parse_log_file(log_file):
    # map from a packing to a map from tiling to the its mean execution time
    benchmark_means_map = {}
    # map from a packing to a map from tiling to the stddev of its execution time
    benchmark_stddev_map = {}
    # map from a packing to a map from tiling to the confidence interval of its execution time
    benchmark_confidence_intervals_map = {}
    # stores all packing options used in all tilings
    tilings_run = set()
    iterations_per_run = -1

    with open(log_file, 'r') as f:
        for line in f:
            if "Running" in line:
                tiling,packing = line.split('/')[-1].replace('./' + benchmark_name + '-', '').replace('.exe', '').replace('Running ', '').strip('\n').split('-packing-')
                tiling = '-'.join(tiling.split('-')[1:])
                tiling = int(tiling.split('-')[-1])

            if "mean" in line:
                mean_value = float(line.split()[3])
                iterations = int(line.split()[5])
                if iterations_per_run == -1:
                    iterations_per_run = iterations
                else:
                    assert iterations == iterations_per_run

            if "stddev" in line:
                stddev_value = float(line.split()[3])
                tilings_run.add(tiling)

                # results were collected for this sample
                if packing not in benchmark_means_map:
                    benchmark_means_map[packing] = {}
                    benchmark_stddev_map[packing] = {}
                    benchmark_confidence_intervals_map[packing] = {}

                benchmark_means_map[packing][tiling] = mean_value
                benchmark_stddev_map[packing][tiling] = stddev_value

                conf_low, conf_high = st.norm.interval(alpha=0.95, loc=mean_value, scale=stddev_value/sqrt(iterations))
                conf = (conf_high - conf_low) / 2
                benchmark_confidence_intervals_map[packing][tiling] = conf

    return benchmark_means_map, benchmark_stddev_map, benchmark_confidence_intervals_map, iterations, tilings_run

# parse perf results
def parse_perf_log_file(log_file):
    # map from perf counter to a map from a packing to a map from a tiling to the value of the counter
    perf_counter_map = {}

    with open(log_file, 'r') as f:
        collectPerf = False
        errorFound = False
        for line in f:
            # skip empty lines
            if line.strip() == '':
                continue

            if "abort" in line.lower() or "segmentation fault" in line.lower():
                errorFound = True
                continue

            if "Running" in line:
                errorFound = False
                tiling,packing = line.split('/')[-1].replace('./' + benchmark_name + '-', '').replace('.exe', '').replace('Running ', '').strip('\n').split('-packing-')
                tiling = '-'.join(tiling.split('-')[1:])
                tiling = int(tiling.split('-')[-1])
            # start of perf information
            elif "Performance counter stats" in line and not errorFound:
                collectPerf = True
            # end of perf information
            elif "seconds time elapsed" in line and not errorFound:
                collectPerf = False
            elif collectPerf and not errorFound:
                value = int(line.split()[0].replace(',',''))
                counter = line.split()[1]
                if counter not in perf_counter_map:
                    perf_counter_map[counter] = {}
                if packing not in perf_counter_map[counter]:
                    perf_counter_map[counter][packing] = {}
                perf_counter_map[counter][packing][tiling] = value

    return perf_counter_map

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Parse output logs of packing selection evaluation")

    parser.add_argument("input_file", help="Log obtained with run.sh")
    parser.add_argument("output_dir", help="Output dir")
    parser.add_argument('benchmark_name', choices=['2mm', 'gemm', 'gemm-blis'], type=str, help="Benchmark used in generate-files.sh")
    parser.add_argument("--skip-perf-graphs", help="Do not generate perf graphs.", action='store_true')
    args = parser.parse_args()

    input_file = Path(args.input_file)
    output_dir = Path(args.output_dir)
    benchmark_name = args.benchmark_name
    skip_perf_graphs = args.skip_perf_graphs

    if not input_file.exists() or not input_file.is_file():
        print("Input file is not a file of does not exist", file=sys.stderr)
        sys.exit(1)

    if not output_dir.exists() or not output_dir.is_dir():
        print("Output dir does not exist", file=sys.stderr)
        sys.exit(1)

    input_file = input_file.absolute()
    output_dir = output_dir.absolute()

    # Parse input file
    benchmark_mean, benchmark_stddev, benchmark_confidence_interval, iterations_per_run, tiling_legend = parse_log_file(input_file)

    # Output paths
    output_csv = output_dir / "output.csv"
    perf_outputs_dir = output_dir / "perf"
    perf_relative_outputs_dir = output_dir / "perf-relative"
    output_perf_csv = output_dir / "output-perf.csv"

    perf_counters = set()
    perf_results = dict()

    # get perf counters that were measured
    with open(input_file, 'r') as f:
        collectPerf = False
        for line in f:
            # skip emtpy lines
            if line.strip() == '':
                continue

            # start of perf information
            if "Performance counter stats" in line:
                collectPerf = True
            # end of perf information
            elif "seconds time elapsed" in line:
                break
            elif collectPerf:
                perf_counters.add(line.split()[1])

    # Check if perf was measured
    perf_found = True
    if skip_perf_graphs:
        perf_found = False
    elif len(perf_counters) == 0:
        perf_found = False
        print("Warning: No perf data was found")
    else:
        perf_outputs_dir.mkdir(exist_ok=True)
        perf_relative_outputs_dir.mkdir(exist_ok=True)

    # Dump .csv data
    with open(output_csv, 'w') as f:
        # Write header
        f.write("benchmark,tiling,packing,mean time (ms),stddev,95% confidence interval,iterations run\n")
        for packing in sorted(benchmark_mean.keys()):
            for tiling in sorted(benchmark_mean[packing].keys()):
                f.write(benchmark_name + "," + str(tiling) + "," + packing + "," + str(benchmark_mean[packing][tiling]) + "," + str(benchmark_stddev[packing][tiling]) + "," + str(benchmark_confidence_interval[packing][tiling]) + "," + str(iterations_per_run) + "\n")

    if perf_found:
        # parse perf results
        perf_results = parse_perf_log_file(input_file)
        # Dump perf .csv data
        with open(output_perf_csv, 'w') as f:
            # Write header
            header = "benchmark,tiling,packing,"
            header = header + ','.join(sorted(perf_counters)) + ",iterations" + "\n"
            f.write(header)
            for packing in sorted(benchmark_mean.keys()):
                for tiling in sorted(benchmark_mean[packing].keys()):
                    csv_output_line = benchmark_name + "," + str(tiling) + "," + packing + ","
                    # get the values for this packing for every counter in this tiling
                    counter_values = [str(perf_results[counter][packing][tiling]) for counter in sorted(perf_counters)]
                    csv_output_line = csv_output_line + ','.join(counter_values) + ',' + str(iterations_per_run) + '\n'
                    f.write(csv_output_line)

    # from matplotlib import rc
    # rc('font',**{'family':'serif','serif':['Libertine']})
    # rc('text', usetex=True)
    # rc('text.latex',
    #    preamble="\n".join([ # plots will use this preamble
    #     r"\usepackage[utf8]{inputenc}",
    #     r"\usepackage[T1]{fontenc}",
    #     r"\usepackage{libertine}",
    #     ])
    #   )
    # plt.style.use('seaborn-whitegrid')
    # plt.rcParams.update({
    #     "font.size": 18,
    #     "font.family": "serif",
    #     "legend.fontsize": 16,
    # })
    plt.style.use('seaborn-whitegrid')
    plt.rcParams.update({
        "font.size": 18,
        "font.family": "Dejavu Serif",
        "legend.fontsize": 16,
    })
    marker=['o', 'v', '^', '<', '>', 's', 'p', '*', 'X']

    none_packing_idx = "none"
    heuristic_packing_idx = "heuristic"

    polymer_label = ""
    if benchmark_name == "gemm-blis":
        polymer_label = "Polymer + BLIS Interchange"
    else:
        polymer_label = "Polymer"

    # Build the plot for all packings together (time) ----------------
    fig, ax = plt.subplots()
    for idx,packing in enumerate(sorted(benchmark_mean.keys())):
        label = packing
        if packing == heuristic_packing_idx:
            continue
        elif packing == none_packing_idx:
            label = polymer_label
        y_time = []
        y_conf = []
        x_tilings = sorted(benchmark_mean[packing].keys())
        for tiling in x_tilings:
            y_time.append(benchmark_mean[packing][tiling])
            y_conf.append(benchmark_confidence_interval[packing][tiling])
        ax.errorbar(x_tilings, y_time, yerr=y_conf, label=label, markersize=sqrt(12), markeredgecolor='black', markeredgewidth=0.2, ecolor='black', elinewidth=0.5, fmt=marker[idx%len(marker)], alpha=0.8)
    # Set axes labels and limits
    ax.set_ylim(bottom=0)
    ax.set_xlim(left=min(x_tilings)-2, right=max(x_tilings)+2)
    ax.yaxis.grid(True)
    ax.xaxis.grid(True)
    ax.grid(which='both', alpha=0.3)
    ax.set_ylabel('CPU Time (ms)')
    ax.set_xlabel('Tiling size (all dimensions)')
    # Save the figure and show
    graph_path = output_dir / ('all-graphs-time.png')
    if benchmark_name == "gemm-blis":
        legend = plt.legend(ncol=3, loc='lower center', frameon=True, framealpha=1, bbox_to_anchor=(0.5, 1), columnspacing=0.8, handletextpad=0.3, handlelength=1.0)
    else:
        legend = plt.legend(ncol=6, loc='lower center', frameon=True, framealpha=1, bbox_to_anchor=(0.5, 1), columnspacing=0.8, handletextpad=0.3, handlelength=1.0)
    frame = legend.get_frame()
    frame.set_facecolor('white')
    frame.set_edgecolor('black')
    plt.savefig(graph_path, bbox_inches='tight', dpi=300)
    plt.close(fig)
    # ----------------------------------------------------------------

    # Build the plot for all packings together (time area) ----------------
    fig, ax = plt.subplots()
    y_max_time = []
    y_min_time = []
    y_no_packing = []
    y_no_packing_conf = []
    y_packing_heuristic = []
    y_packing_heuristic_conf = []
    x_packing_heuristic_tilings = []
    x_tilings = sorted(tiling_legend)
    for tiling in sorted(tiling_legend):
        packing_times = []
        for packing in benchmark_mean.keys():
            if packing != heuristic_packing_idx and tiling in benchmark_mean[packing]:
                packing_times.append(benchmark_mean[packing][tiling])

        y_max_time.append(max(packing_times))
        y_min_time.append(min(packing_times))
        y_no_packing.append(benchmark_mean[none_packing_idx][tiling])
        y_no_packing_conf.append(benchmark_confidence_interval[none_packing_idx][tiling])

        if tiling in benchmark_mean[heuristic_packing_idx]:
            y_packing_heuristic.append(benchmark_mean[heuristic_packing_idx][tiling])
            y_packing_heuristic_conf.append(benchmark_confidence_interval[heuristic_packing_idx][tiling])
            x_packing_heuristic_tilings.append(tiling)
    ax.fill_between(x_tilings, y_max_time, y_min_time, alpha=0.3, color='#fdb863', label="Individual Packings")

    ax.errorbar(x_tilings, y_no_packing, yerr=y_no_packing_conf, label=polymer_label, markersize=sqrt(18), markerfacecolor='#5e3c99', markeredgecolor='black', markeredgewidth=0.5, ecolor='black', elinewidth=0.5, fmt='o', alpha=1)
    ax.errorbar(x_packing_heuristic_tilings, y_packing_heuristic, yerr=y_packing_heuristic_conf, label=polymer_label + " + GPAT", markersize=sqrt(18), markerfacecolor='#e66101', markeredgecolor='black', markeredgewidth=0.5, ecolor='black', elinewidth=0.5, fmt='s', alpha=0.8)

    # Set axes labels and limits
    ax.set_ylim(bottom=0)
    ax.set_xlim(left=min(x_tilings)-2, right=max(x_tilings)+2)
    ax.yaxis.grid(True)
    ax.xaxis.grid(True)
    ax.grid(which='both', alpha=0.3)
    ax.set_ylabel('CPU Time (ms)')
    ax.set_xlabel('Tiling size (all dimensions)')
    # Save the figure and show
    graph_path = output_dir / ('all-graphs-time-area.png')
    if benchmark_name == "gemm-blis":
        legend = plt.legend(ncol=1, loc='lower center', frameon=True, framealpha=1, bbox_to_anchor=(0.5, 1), columnspacing=0.8, handletextpad=0.3, handlelength=1.0)
    else:
        legend = plt.legend(ncol=2, loc='lower center', frameon=True, framealpha=1, bbox_to_anchor=(0.5, 1), columnspacing=0.8, handletextpad=0.3, handlelength=1.0)
    frame = legend.get_frame()
    frame.set_facecolor('white')
    frame.set_edgecolor('black')
    plt.savefig(graph_path, bbox_inches='tight', dpi=300)
    plt.close(fig)
    # ----------------------------------------------------------------

    # Build the plot for all packings together (speedup on none) -----
    fig, ax = plt.subplots()
    ax.axhline(y=1, color='black', linestyle='--', alpha=0.5, linewidth=1)
    for idx,packing in enumerate(sorted(benchmark_mean.keys())):
        if packing == none_packing_idx or packing == heuristic_packing_idx:
            continue
        y_speedup = []
        x_tilings = sorted(benchmark_mean[packing].keys())

        for tiling in x_tilings:
            y_speedup.append(benchmark_mean[none_packing_idx][tiling]/benchmark_mean[packing][tiling])
        bars = ax.scatter(x_tilings, y_speedup, marker=marker[idx%len(marker)], s=12, edgecolor='black', linewidths=0.2, alpha=0.8, label=packing)
    # Set axes labels and limits
    ax.set_xlim(left=min(x_tilings)-2, right=max(x_tilings)+2)
    ax.yaxis.grid(True)
    ax.xaxis.grid(True)
    ax.grid(which='both', alpha=0.3)
    ax.set_ylabel('Speedup over ' + polymer_label)
    if benchmark_name == "gemm-blis":
        ax.set_ylabel('Speedup over\n' + polymer_label)
    ax.set_xlabel('Tiling size')
    # Save the figure and show
    graph_path = output_dir / ('all-graphs-speedup.png')
    legend = plt.legend(ncol=6, loc='lower center', frameon=True, framealpha=1, bbox_to_anchor=(0.5, 1), columnspacing=0.8, handletextpad=0.3, handlelength=1.0)
    frame = legend.get_frame()
    frame.set_facecolor('white')
    frame.set_edgecolor('black')
    plt.savefig(graph_path, bbox_inches='tight', dpi=300)
    plt.close(fig)
    # ----------------------------------------------------------------

    # Build the plot for all packings together (speedup area) --------
    fig, ax = plt.subplots()
    ax.axhline(y=1, color='black', linestyle='--', alpha=0.5, linewidth=1)
    y_max_time = []
    y_min_time = []
    y_packing_heuristic = []
    x_packing_heuristic_tilings = []
    x_tilings = sorted(tiling_legend)
    for tiling in sorted(tiling_legend):
        packing_times = []
        for packing in benchmark_mean.keys():
            if packing != heuristic_packing_idx and tiling in benchmark_mean[packing]:
                packing_times.append(benchmark_mean[packing][tiling])

        y_max_time.append(benchmark_mean[none_packing_idx][tiling]/max(packing_times))
        y_min_time.append(benchmark_mean[none_packing_idx][tiling]/min(packing_times))

        if tiling in benchmark_mean[heuristic_packing_idx]:
            y_packing_heuristic.append(benchmark_mean[none_packing_idx][tiling]/benchmark_mean[heuristic_packing_idx][tiling])
            x_packing_heuristic_tilings.append(tiling)
    ax.fill_between(sorted(tiling_legend), y_max_time, y_min_time, alpha=0.3, color='#fdb863', label="Individual Packings")
    ax.scatter(x_packing_heuristic_tilings, y_packing_heuristic, label=polymer_label + " + GPAT", s=18, facecolor='#e66101', edgecolor='black', linewidth=0.5, marker='s', alpha=1)
    ax.set_xlim(left=min(x_tilings)-2, right=max(x_tilings)+2)
    ax.yaxis.grid(True)
    ax.xaxis.grid(True)
    ax.grid(which='both', alpha=0.3)
    ax.set_ylabel('Speedup over ' + polymer_label)
    if benchmark_name == "gemm-blis":
        ax.set_ylabel('Speedup over\n' + polymer_label)
    ax.set_xlabel('Tiling size (all dimensions)')
    # Save the figure and show
    graph_path = output_dir / ('all-graphs-speedup-area.png')
    if benchmark_name == "gemm-blis":
        legend = plt.legend(ncol=1, loc='lower center', frameon=True, framealpha=1, bbox_to_anchor=(0.5, 1), columnspacing=0.8, handletextpad=0.3, handlelength=1.0)
    else:
        legend = plt.legend(ncol=2, loc='lower center', frameon=True, framealpha=1, bbox_to_anchor=(0.5, 1), columnspacing=0.8, handletextpad=0.3, handlelength=1.0)
    frame = legend.get_frame()
    frame.set_facecolor('white')
    frame.set_edgecolor('black')
    plt.savefig(graph_path, bbox_inches='tight', dpi=300)
    plt.close(fig)
    # ----------------------------------------------------------------

    if perf_found:
        # Build the plot for all packings together for perf counters (area) -----
        for counter in perf_counters:
            fig, ax = plt.subplots()
            y_max = []
            y_min = []
            y_no_packing = []
            y_packing_heuristic = []
            x_tilings = sorted(tiling_legend)
            x_packing_heuristic_tilings = []
            for tiling in x_tilings:
                packing_times = []
                for packing in sorted(perf_results[counter].keys()):
                    if packing != heuristic_packing_idx and tiling in perf_results[counter][packing]:
                        packing_times.append(perf_results[counter][packing][tiling]/iterations_per_run)
                y_max.append(max(packing_times))
                y_min.append(min(packing_times))
                y_no_packing.append(perf_results[counter][none_packing_idx][tiling]/iterations_per_run)
                if tiling in perf_results[counter][heuristic_packing_idx]:
                    y_packing_heuristic.append(perf_results[counter][heuristic_packing_idx][tiling]/iterations_per_run)
                    x_packing_heuristic_tilings.append(tiling)
            ax.fill_between(x_tilings, y_max, y_min, alpha=0.3, color='#fdb863', label="Individual Packings")
            ax.scatter(x_tilings, y_no_packing, label=polymer_label, s=18, facecolor='#5e3c99', edgecolor='black', linewidths=0.5, marker='o', alpha=1)
            ax.scatter(x_packing_heuristic_tilings, y_packing_heuristic, label=polymer_label + " + GPAT", s=18, facecolor='#e66101', edgecolor='black', linewidths=0.5, marker='s', alpha=0.8)
            # Set axes labels and limits
            ax.set_ylim(bottom=0)
            ax.set_xlim(left=min(x_tilings)-2, right=max(x_tilings)+2)
            ax.yaxis.grid(True)
            ax.xaxis.grid(True)
            ax.grid(which='both', alpha=0.3)
            ax.set_ylabel(counter)
            ax.set_xlabel('Tiling size (all dimensions)')
            # Save the figure and show
            graph_path = perf_outputs_dir / (counter + '-area.png')
            if benchmark_name == "gemm-blis":
                legend = plt.legend(ncol=1, loc='lower center', frameon=True, framealpha=1, bbox_to_anchor=(0.5, 1.05), columnspacing=0.8, handletextpad=0.3, handlelength=1.0)
            else:
                legend = plt.legend(ncol=2, loc='lower center', frameon=True, framealpha=1, bbox_to_anchor=(0.5, 1.05), columnspacing=0.8, handletextpad=0.3, handlelength=1.0)
            frame = legend.get_frame()
            frame.set_facecolor('white')
            frame.set_edgecolor('black')
            plt.savefig(graph_path, bbox_inches='tight', dpi=300)
            plt.close(fig)
        # -----------------------------------------------------------------------

        # Build the plot for all packings together for perf counters -----
        for counter in perf_counters:
            fig, ax = plt.subplots()
            for idx,packing in enumerate(sorted(perf_results[counter].keys())):
                label = packing
                if packing == heuristic_packing_idx:
                    continue
                elif packing == none_packing_idx:
                    label = polymer_label
                y_values = []
                x_tilings = []
                for tiling in sorted(perf_results[counter][packing].keys()):
                    y_values.append(perf_results[counter][packing][tiling]/iterations_per_run)
                    x_tilings.append(tiling)
                bars = ax.scatter(x_tilings, y_values, marker=marker[idx%len(marker)], s=12, edgecolor='black', linewidths=0.2, alpha=0.8, label=label)
            # Set axes labels and limits
            ax.set_ylim(bottom=0)
            ax.set_xlim(left=min(x_tilings)-2, right=max(x_tilings)+2)
            ax.yaxis.grid(True)
            ax.xaxis.grid(True)
            ax.grid(which='both', alpha=0.3)
            ax.set_ylabel(counter)
            ax.set_xlabel('Tiling size (all dimensions)')
            # Save the figure and show
            graph_path = perf_outputs_dir / (counter + '.png')
            if benchmark_name == "gemm-blis":
                legend = plt.legend(ncol=3, loc='lower center', frameon=True, framealpha=1, bbox_to_anchor=(0.5, 1.05), columnspacing=0.8, handletextpad=0.3, handlelength=1.0)
            else:
                legend = plt.legend(ncol=6, loc='lower center', frameon=True, framealpha=1, bbox_to_anchor=(0.5, 1.05), columnspacing=0.8, handletextpad=0.3, handlelength=1.0)
            frame = legend.get_frame()
            frame.set_facecolor('white')
            frame.set_edgecolor('black')
            plt.savefig(graph_path, bbox_inches='tight', dpi=300)
            plt.close(fig)
        # ----------------------------------------------------------------

        # Build the plot for all packings together for perf counters relative to no packing (area) -----
        for counter in perf_counters:
            fig, ax = plt.subplots()
            ax.axhline(y=1, color='black', linestyle='--', alpha=0.5, linewidth=1)
            y_max = []
            y_min = []
            y_packing_heuristic = []
            x_tilings = sorted(tiling_legend)
            x_packing_heuristic_tilings = []
            for tiling in x_tilings:
                packing_times = []
                for packing in sorted(perf_results[counter].keys()):
                    if packing != heuristic_packing_idx and tiling in perf_results[counter][packing]:
                        packing_times.append(perf_results[counter][packing][tiling])
                y_max.append(perf_results[counter][none_packing_idx][tiling]/max(packing_times))
                y_min.append(perf_results[counter][none_packing_idx][tiling]/min(packing_times))
                if tiling in perf_results[counter][heuristic_packing_idx]:
                    y_packing_heuristic.append(perf_results[counter][none_packing_idx][tiling]/perf_results[counter][heuristic_packing_idx][tiling])
                    x_packing_heuristic_tilings.append(tiling)
            ax.fill_between(x_tilings, y_max, y_min, alpha=0.3, color='#fdb863', label="Individual Packings")
            ax.scatter(x_packing_heuristic_tilings, y_packing_heuristic, label=polymer_label + " + GPAT", s=18, facecolor='#e66101', edgecolor='black', linewidth=0.5, marker='s', alpha=0.8)
            # Set axes labels and limits
            ax.set_xlim(left=min(x_tilings)-2, right=max(x_tilings)+2)
            ax.yaxis.grid(True)
            ax.xaxis.grid(True)
            ax.grid(which='both', alpha=0.3)
            ax.set_ylabel(counter + "\nreduction over " + polymer_label)
            if benchmark_name == "gemm-blis":
                ax.set_ylabel(counter + "\nreduction over\n" + polymer_label)
            ax.set_xlabel('Tiling size (all dimensions)')
            # Save the figure and show
            graph_path = perf_relative_outputs_dir / (counter + '-area.png')
            legend = plt.legend(loc='lower center', frameon=True, framealpha=1, bbox_to_anchor=(0.5, 1), columnspacing=0.8, handletextpad=0.3, handlelength=1.0)
            frame = legend.get_frame()
            frame.set_facecolor('white')
            frame.set_edgecolor('black')
            plt.savefig(graph_path, bbox_inches='tight', dpi=300)
            plt.close(fig)
         # ----------------------------------------------------------------------------------------------

        # Build the plot for all packings together for perf counters relative to no packing -------
        for counter in perf_counters:
            fig, ax = plt.subplots()
            ax.axhline(y=1, color='black', linestyle='--', alpha=0.5, linewidth=1)
            for idx,packing in enumerate(sorted(perf_results[counter].keys())):
                if packing == heuristic_packing_idx or packing == none_packing_idx:
                    continue
                y_values = []
                x_tilings = []
                for tiling in sorted(perf_results[counter][packing].keys()):
                    y_values.append(perf_results[counter][none_packing_idx][tiling]/perf_results[counter][packing][tiling])
                    x_tilings.append(tiling)
                bars = ax.scatter(x_tilings, y_values, marker=marker[idx%len(marker)], s=12, edgecolor='black', linewidths=0.2, alpha=0.8, label=packing)
            # Set axes labels and limits
            ax.set_xlim(left=min(x_tilings)-2, right=max(x_tilings)+2)
            ax.yaxis.grid(True)
            ax.xaxis.grid(True)
            ax.grid(which='both', alpha=0.3)
            ax.set_ylabel(counter + "\nreduction over " + polymer_label)
            if benchmark_name == "gemm-blis":
                ax.set_ylabel(counter + "\nreduction over\n" + polymer_label)
            ax.set_xlabel('Tiling size')
            # Save the figure and show
            graph_path = perf_relative_outputs_dir / (counter + '.png')
            legend = plt.legend(ncol=6, loc='lower center', frameon=True, framealpha=1, bbox_to_anchor=(0.5, 1), columnspacing=0.8, handletextpad=0.3, handlelength=1.0)
            frame = legend.get_frame()
            frame.set_facecolor('white')
            frame.set_edgecolor('black')
            plt.savefig(graph_path, bbox_inches='tight', dpi=300)
            plt.close(fig)
        # -----------------------------------------------------------------------------------------


