---
title: 'nimCSO: A Nim package for Compositional Space Optimization'
tags:
  - Nim
  - materials science
  - data science
  - compositionally complex materials
  - high entropy alloys
  - high performance computing
  - metaprogramming
authors:
  - name: Adam M. Krajewski
    orcid: 0000-0002-2266-0099
    affiliation: 1
    corresponding: true
  - name: Arindam Debnath
    orcid: 0000-0001-9427-4499
    affiliation: 1
  - name: Wesley F. Reinhart
    orcid: 0000-0001-7256-2123
    affiliation: "1, 2"
  - name: Allison M. Beese
    orcid: 0000-0002-7022-3387
    affiliation: 1
  - name: Zi-Kui Liu
    orcid: 0000-0003-3346-3696
    affiliation: 1
affiliations:
  - name: Department of Materials Science and Engineering, The Pennsylvania State University, USA
    index: 1
  - name: Institute for Computational and Data Sciences, The Pennsylvania State University, USA
    index: 2
date: 14 September 2023
#bibliography: [paper/paper.bib]
bibliography: paper.bib
---


# Summary

`nimCSO` is a high-performance tool implementing several methods for selecting components (data dimensions) in compositional datasets, which optimize the data availability and density for applications such as machine learning. Making said choice is a combinatorically hard problem for complex compositions existing in high-dimensional spaces due to the interdependency of components being present. Such spaces are encountered across many scientific disciplines (see [Statement of Need](#statement-of-need)), including materials science, where datasets on Compositionally Complex Materials (CCMs) often span 20-45 chemical elements, 5-10 processing types, and several temperature regimes, for up to 60 total data dimensions. This challenge also exists in everyday contexts, such as study of cooking ingredients [@Ahn2011], which interact in various recipes, giving rise to questions like *"Given 100 spices at the supermarket, which 20, 30, or 40 should I stock in my pantry to maximize the number of unique dishes I can spice according to recipe?"*. Critically, this is not as simple as frequency-based selection because, e.g., removing less common nutmeg and cinnamon from your shopping list will prevent many recipes with the frequent vanilla, but won't affect those using black pepper [@Edmisten2022].

At its core, `nimCSO` leverages the metaprogramming ability of the Nim language [@Rumpf2023] to optimize itself at compile time, both in terms of speed and memory handling, to the specific problem statement and dataset at hand based on a human-readable configuration file. As demonstrated in the [Methods and Performance](#methods-and-performance) section, `nimCSO` reaches the physical limits of the hardware (L1 cache latency) and can outperform an efficient native Python implementation over 100 times in terms of speed and 50 times in terms of memory usage (*not* counting interpreter), while also outperforming NumPy implementation 37 and 17 times, respectively, when checking a candidate solution.

`nimCSO` is designed to be both (1) a user-ready tool, implementing two efficient brute-force approaches (for handling up to 25 dimensions), a custom search algorithm (for up to 40 dimensions), and a genetic algorithm (for any dimensionality), and (2) a scaffold for building even more elaborate methods in the future, including heuristics going beyond data availability. All configuration is done with a simple human-readable `YAML` config file and plain text data files, making it easy to modify the search method and its parameters with no knowledge of programming and only basic command line skills.


# Statement of Need

`nimCSO` is an interdisciplinary tool applicable to any field where data is composed of a large number of independent components and their interaction is of interest in a modeling effort, ranging from economics where factor selection affects performance of analytical [@Fan2013] and ML [@Peng2021] models, through medicine where drug interactions can have a significant impact on the treatment [@Maher2014] (an escalating problem [@Guthrie2015]) and understanding of microbial interactions can help fight gastrointenstant problems [@Leeuwen2023; @Berg2022], to materials science, where the composition and processing history are critical to resulting properties. The latter has been the root motivation for the development of `nimCSO` within the [ULTERA Project (ultera.org)](https://ultera.org) carried under the [US DOE ARPA-E ULTIMATE](https://arpa-e.energy.gov/?q=arpa-e-programs/ultimate) program, which aims to develop a new generation of ultra-high temperature materials for aerospace applications, through generative machine learning models [@Debnath2021] driving thermodynamic modeling, alloy design, and manufacturing [@Li2024].

One of the most promising materials for such applications are the aforementioned CCMs and their metal-focused subset of Refractory High Entropy Alloys (RHEAs) [@Senkov2018], which have rapidly grown since first proposed by [@Cantor2004] and [@Yeh2004]. Contrary to most of the traditional alloys, they contain many chemical elements (typically 4-9) in similar proportions in the hope of thermodynamically stabilizing the material by increasing its configurational entropy ($\Delta S_{conf} = \Sigma_i^N x_i \ln{x_i}$ for ideal mixing of $N$ elements with fractions $x_i$), which encourages sampling from a large palette of chemical elements. At the time of writing, the ULTERA Database is the largest collection of HEA data, containing over 7,000 points manually extracted from 560 publications. It covers 37 chemical elements resulting in extremely large compositional spaces [@Krajewski2024Nimplex]; thus, it becomes critical to answer questions like *"Which combination of how many elements will unlock the most expansive and simultaneously dense dataset?"* which has $2^{37}-1$ or 137 billion possible solutions.

Another significant example of intended use is to perform similar optimizations over large (many millions) datasets of quantum mechanics calculations spanning 93 chemical elements and accessible through the OPTIMADE API [@Evans2024].


# Methods and Performance

## Overview

As shown in Figure \ref{fig:main}, `nimCSO` can be used as a user-tool based on human-readable configuration and a data file containing data "elements" which can be any strings representing problem-specific names of, e.g., spices, market stocks, drug names, or chemical systems. A single command is used to recompile (`nim c -f`) and run (`-r`) problem (`-d:configPath=config.yaml`) with `nimCSO` (`src/nimcso`) using one of several methods. Advanced users can also quickly customize the provided methods with brief scripts using the `nimCSO` as a data-centric library.

![Schematic of core nimCSO data flow with a description of key methods. Metaprogramming is used to compile the software optimized to the human-readable data and configuration files at hand.\label{fig:main}](assets/nimCSO_mainFigure.png){width="300pt"}

Internally, `nimCSO` is built around storing the data and solutions in one of two ways. The first is as bits inside an integer (`uint64`), which allows for the highest speed and lowest memory consumption possible but is limited to 64 dimensions and does not allow for easy extension to other use cases; thus, as of publication, it is used only in a particular `bruteForceInt` routine. The second one, used in `bruteForce`, `algorithmSearch`, and `geneticSearch`, implements a custom easily extensible `ElSolution` type containing heuristic value and `BitArray` payload, which is defined at compile time based on the configuration file to minimize necessary overheads. As shown in Table 1, both encodings outperform typical native Python and NumPy implementations, typically used in this application by the scientific community, which can be found in `benchmarks` directory.

+----------------+----------------+------------------+-----------------------------+----------------------------+
| Tool           | Object         | Time per Dataset | Time per Entry *(Relative)* | Database Size *(Relative)* |
+:===============+:===============+:================:+:===========================:+:==========================:+
| `Python`^3.11^ | `set`          | 107.5 µs         | 50.0 ns *(x1)*              | 871.5 kB *(x1)*            |
+----------------+----------------+------------------+-----------------------------+----------------------------+
| `NumPy`^1.26^  | `array`        | 36.4 µs          | 16.9 ns  *(x3.0)*           | 79.7 kB  *(x10.9)*         |
+----------------+----------------+------------------+-----------------------------+----------------------------+
| `nimCSO`^0.6^  | `BitArray`     | 6.9 µs           | 3.2 ns   *(x15.6)*          | 50.4 kB  *(x17.3)*         |
+----------------+----------------+------------------+-----------------------------+----------------------------+
| `nimCSO`^0.6^  |`uint64`        | 0.98 µs          | 0.456 ns  *(x110)*          | 16.8 kB  *(x52)*           |
+================+================+==================+=============================+============================+

Table: Benchmarks of (1) the average time to evaluate how many datapoints would be lost if 5 selected components were removed from a dataset with 2,150 data points spanning 37 components, averaged over 10,000 runs, and (2) the size of the data structure representing the dataset. Values were obtained by running scripts in `benchmarks` directory on Apple M2 Max CPU. Pre-processing time is excluded, as it has negligible impact on larger, realistic problems.


## Brute-Force Search

The brute-force search is a naïve method of evaluating all possibilities; however, its near-zero overhead can make it the most efficient for small problems. In this implementation, all entries in the *power set* of $N$ considered elements are represented as a range of integers from $0$ to $2^{N} - 1$, and used to initialize `uint64`/`BitArray`s on the fly. To minimize the memory footprint of solutions, the algorithm only keeps track of the best solution for a given number of elements present in the solution. Current implementations are limited to 64 elements, as it is not feasible beyond approximately 30 elements; however, the one based on `BitArray` could be easily extended if needed.


## Algorithm-Based Search

The algorithm implemented in the `algorithmSearch` routine, targeting high dimensional problems (20-50), iteratively expands and evaluates candidates from a priority queue (implemented through an efficient binary heap [@Williams1964]) while leveraging the fact that *the number of data points lost when removing elements `A` and `B` from the dataset has to be at least as large as when removing either `A` or `B` alone* to delay exploration of candidates until they *can* contribute to the solution. Furthermore, to (1) avoid revisiting the same candidate without keeping track of visited states and to (2) avoid exhaustive search by inhibiting the exploration of unlikely candidates, the algorithm *assumes* that while searching for a given order of solution, elements present in already expanded solutions will not improve those not yet expanded. This effectively prunes candidate branches requiring two or more levels of backtracking, making the algorithm computationally feasible in higher-dimensional problems at the cost of potentially suboptimal results. In the authors' tests over HEAs, this algorithm has generated correct results (agreeing with an exhaustive `bruteForce` exploration), except for occasional differences in the last explored solution, where almost all data was discarded, and a few remaining points were highly independent.

## Genetic Search

Beyond 50 components, the [algorithm-based](#algorithm-based-search) method will likely run out of memory on most personal systems. The `geneticSearch` routine resolves this issue through an evolution strategy to iteratively improve solutions based on custom `mutate` and `crossover` procedures. Both are of uniform type [@Goldberg1989] with additional constraint of Hamming weight [@Knuth] preservation in order to preserve number of considered elements in parents and offspring. In `mutate` this is achieved by using purely random bit swapping, rather than more common flipping, as demonstrated in the Figure \ref{fig:mutate}.

![Schematic of `mutate` procedure where bits are swapping randomly, so that (1) bit can swap itself, (2) bits can swap causing a flip, or (3) bits can swap with no effect.\label{fig:mutate}](assets/nimcso_mutate.drawio.png){width="95pt"}

Meanwhile, in `crossover`, this constraint is satisfied by passing overlapping bits directly, while non-overlapping bits are shuffled and distributed at positions present in one of the parents, as shown in Figure \ref{fig:crossover}.

![Schematic of uniform `crossover` procedure preserving Hamming weight implemented in `nimCSO`. \label{fig:crossover}](assets/nimcso_crossover.drawio.png){width="300pt"}

The above are applied iteratively, with best solutions carried to next generation, until the solution converges or the maximum number of iterations is reached. Unlike the other methods, the present method is not limited by the number of components and lets user control both time and memory requirements, either to make big problems feasible or to get a good-enough solution quickly in small problems. However, it comes with no optimality guarantees.


# Use Examples

The tool comes with two pre-defined example problems to demonstrate its use. The first one is defined in the default `config.yaml` file and goes through the complete dataset of 2,150 data points spanning 37 components in `dataList.txt` based on the ULTERA Dataset [@Debnath2021]. It is intended to showcase `algorithmSearch`/`-as` and `geneticSearch`/`-gs` methods, as brute-forcing would take around one day. The second one is defined in `config_rhea.yaml` and uses the same dataset but a limited scope of components critical to RHEAs [@Senkov2018] and is intended to showcase `bruteForce`/`-bf` and `bruteForceInt`/`-bfi` methods. With four simple commands (see Table 2), the user can compare the methods' performance and the solutions' quality.

+--------------------------------------------------+----------+-------------+
| Task Definition (`nim c -r -f -d:release ...`)   | Time (s) | Memory (MB) |
+:=================================================+:=========+:===========:+
| `-d:configPath=config.yaml src/nimcso -as`       | 308s     | 488 MB      |
+--------------------------------------------------+----------+-------------+
| `-d:configPath=config.yaml src/nimcso -gs`       | 5.10s    | 3.2 MB      |
+--------------------------------------------------+----------+-------------+
| `-d:configPath=config_rhea.yaml src/nimcso -as`  | 0.073s   | 2.2 MB      |
+--------------------------------------------------+----------+-------------+
| `-d:configPath=config_rhea.yaml src/nimcso -gs`  | 0.426s   | 2.1 MB      |
+--------------------------------------------------+----------+-------------+
| `-d:configPath=config_rhea.yaml src/nimcso -bf`  | 3.726s   | 2.0 MB      |
+--------------------------------------------------+----------+-------------+
| `-d:configPath=config_rhea.yaml src/nimcso -bfi` | 0.495s   | 2.0 MB      |
+--------------------------------------------------+----------+-------------+

Table: Four example tasks alongside typical CPU time and memory usage on Apple M2 Max.

In case of issues, the help message can be accessed by running the tool with `-h` flag or by refering to documentation at [amkrajewski.github.io/nimCSO](https://amkrajewski.github.io/nimCSO).


# Contributions

A.M.K. was reponsible for conceptualization, methodology, software, testing and validation, writing of manuscript, and visualization; A.D. was responsible for testing software and results in training machine learning models; A.M.B., W.F.R., Z-K.L. were responsible for funding acquisition, review, and editing. Z-K.L. was also supervising the work.

# Acknowledgements

This work has been funded through grants: **DOE-ARPA-E DE-AR0001435**, **NSF-POSE FAIN-2229690**, and **ONR N00014-23-2721**. We would also like to acknowledge Dr. Jonathan Siegel at Texas A&M University for several valuable discussions and feedback on the project, and Dr. Bradley Dice for his code contributions to the project during the review process, such as optimization of the native Python implementation.


# References
