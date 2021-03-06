#!/usr/bin/env python3

import json
import gzip
import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import re
import seaborn as sns
import argparse
import statsmodels.stats.api as sms
from pandas import DataFrame
from statsmodels.stats.proportion import proportion_confint

__author__ = 'Bence Cserna, modified by Kevin C. Gall'


def flatten(experiment):
    experiment_configuration = experiment.pop('configuration')

    return {**experiment, **experiment_configuration}


def construct_data_frame(data):
    flat_data = [flatten(experiment) for experiment in data]
    return DataFrame(flat_data)


def read_data(file_name):
    if file_name.endswith('.gz'):
        with gzip.open("input.json.gz", "rb") as file:
            return json.loads(file.read().decode("utf-8"))

    with open(file_name) as file:
        return json.load(file)


def set_rc():
    mpl.rcParams['axes.labelsize'] = 10
    mpl.rcParams['xtick.top'] = True
    mpl.rcParams['font.family'] = 'Serif'


def add_row(df, values):
    return df.append(dict(zip(df.columns.values, values)), ignore_index=True)


def plot_domain_instances(data):
    #Each domain configuration
    for domain_path, domain_group in data.groupby(["domainPath"]):
        domain_name = re.search("[^/]+$", domain_path).group(0).rstrip(".vw")

        plt.title(domain_name)
        plt.ylabel('Goal Achievement Time (Factor of Optimal)')
        plt.xlabel('Expansion Limit (Per Iteration)')

        # expansion_series = domain_group["actionDuration"].unique()

        # Each algorithm (different backlog ratios count as different algorithm)
        palette = sns.color_palette(n_colors=10)
        count = 0
        for fields, alg_group in domain_group.groupby(['algorithmName', 'backlogRatio']):
            alg_name = fields[0]
            if fields[0] == "CES":
                alg_name += " Backup Ratio: " + str(fields[1])

            plt.plot('actionDuration', "withinOpt", data=alg_group, color=palette[count], label=alg_name)

            count += 1

        plt.legend()

        plt.savefig("../output/" + domain_name + ".png", format="png")
        plt.figure()


def plot_all_experiments(data, plot_title):
    results = DataFrame(columns="actionDuration withinOpt algorithmName".split())
    cpu_time_results = DataFrame(columns="algorithm cpu_per_iteration_ms, planning_time, iteration_count".split())

    # Change data structure such that goal achievement time is averaged,
    # grouped by action duration and algorithm
    for fields, duration_group in data.groupby(['algorithmName', 'backlogRatio', 'actionDuration']):
        alg_name = fields[0]
        if fields[0] == "CES":
            alg_name += " Backup Ratio: " + str(fields[1])

        # Get mean of within optimal calculation, add row to results dataframe
        mean_within_opt = duration_group['withinOpt'].mean()
        results = add_row(results, [fields[2], mean_within_opt, alg_name])

    for fields, alg_group in data.groupby(['algorithmName', 'backlogRatio']):
        alg_name = fields[0]
        if fields[0] == "CES":
            alg_name += " Backup Ratio: " + str(fields[1])

        mean_planning_time = alg_group['planningTime'].mean()
        mean_iteration_count = alg_group['iterationCount'].mean()
        mean_cpu_time = (alg_group['planningTime'] / alg_group['iterationCount']).mean() / 1000000
        cpu_time_results = add_row(cpu_time_results, [alg_name, mean_cpu_time, mean_planning_time, mean_iteration_count])

    pivot = results.pivot(index="actionDuration", columns="algorithmName", values="withinOpt")

    palette = sns.color_palette(n_colors=10)
    plot = pivot.plot(color=palette, title=plot_title, legend=True)

    plot.set_xscale('log')

    plot.set_xlabel('Expansion Limit (Per Iteration)')
    plot.set_ylabel('Goal Achievement Time (Factor of Optimal)')
    plot.legend(title="")

    plt.savefig("../output/" + plot_title + ".png", format="png")

    cpu_time_results.to_csv("../output/" + plot_title + "_cpu.csv")


def main(individual_plots, paths_to_base, paths, title):
    # results = read_data(path)
    results = []
    for path_name in paths:
        results += read_data(path_name)

    for base_path_name in paths_to_base:
        results += read_data(base_path_name)

    data = construct_data_frame(results)

    # we'll see if we want this...
    set_rc()

    data.drop(['commitmentType', "success", "timeLimit",
               "terminationType", 'timestamp', 'octileMovement', 'lookaheadType',
               'firstIterationDuration', 'generatedNodes', 'expandedNodes',
               "targetSelection", "safetyExplorationRatio", "safetyProof", "safetyWindowSize", "safetyBackup",
               'domainSeed', 'averageVelocity', "proofSuccessful", "rawDomain", "anytimeMaxCount",
               "systemProperties", "towardTopNode", "weight", "numberOfProofs"],
              axis=1,
              inplace=True,
              errors='ignore')

    data = data[~data['errorMessage'].notnull()]

    # Need to default backlogRatio so it is groupable later
    for i, row in data.iterrows():
        if np.isnan(row['backlogRatio']):
            data.at[i, 'backlogRatio'] = 1.0

    astar = data[data["algorithmName"] == "A_STAR"]
    astar["opt"] = astar["actionDuration"] * astar["pathLength"]
    astar = astar[["domainPath", "opt", "actionDuration"]]
    data = pd.merge(data, astar, how='inner', on=["domainPath", 'actionDuration'])
    data["withinOpt"] = data["goalAchievementTime"] / data["opt"]

    if individual_plots:
        plot_domain_instances(data)
    else:
        plot_all_experiments(data, title)


# define command line usage
parser = argparse.ArgumentParser()

parser.add_argument("-b", "--paths_to_base", nargs="*", help="Path to base results JSON",
                    default=["../output/base_results.json"])
parser.add_argument("-p", "--paths", nargs="*", help="Path to experiment results JSON", default=["../output/results.json"])
parser.add_argument("-i", "--individual",
                    help="Should plots be generated for each domain individually? (Primarily for debugging)",
                    action="store_true")
parser.add_argument("-t", "--title", help="Title for plot (ignored for individual plots)", default="Experiments")

args = parser.parse_args()
individual_plots = args.individual
paths_to_base = args.paths_to_base
paths = args.paths
title = args.title


if __name__ == "__main__":
    main(individual_plots, paths_to_base, paths, title)
