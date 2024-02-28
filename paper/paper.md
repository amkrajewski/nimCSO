---
title: 'nimCSO: A Nim package for Compositional Space Optimization'
tags:
  - Nim
  - materials science
  - compositionally complex materials
  - ccm
  - high entropy alloys
  - hea
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

`nimCSO` is a high-performance, low-level tool for selecting components (dimensions) in compositional spaces which optimize the data availability for applications such as machine learning, which is a combinatorically hard problem for complex compositions existing in highly dimensional spaces due to the interdependency of components being present. Such spaces are often encountered in materials science, where datasets on Compositionally Complex Materials (CCMs) often span 20-40 chemical elements, while each data point contains several of them.

This tool employs a set of methods, ranging from (1) brute-force search through (2) genetic algorithms to (3) a newly designed search method. They use custom data structures and procedures written in Nim language, which are compile-time optimized for the specific problem statement and dataset pair, which allows nimCSO to run faster and use 1-2 orders of magnitude less memory than general-purpose data structures. All configuration is done with a simple human-readable config file, allowing easy modification of the search method and its parameters.


# Statement of Need

`nimCSO` is an interdisciplinary tool applicable to any field where data is composed of a large number of independent components and their interaction is of interest in a modeling effort, ranging from social sciences like economics, through medicine where drug interactions can have a large impact on the treatment, to chemistry and materials science, where the composition and processing history are critical to resulting properties. The latter has been the root motivation for the development of `nimCSO` within the [**ULTERA Project**](https://ultera.org) (ultera.org) carried under the [**US DOE ARPA-E ULTIMATE**](https://arpa-e.energy.gov/?q=arpa-e-programs/ultimate) program which aims to develop a new generation of ultra-high temperature materials for aerospace applications, through generative machine learning models [@Debnath2021] driving thermodynamic modelling and experimentation [@Li2023AnExperiments].

One of the most promising materials for these applications are Compositionally Complex Materials (CCMs), and their matal-focused subset of Refractory High Entropy Alloys (RHEAs), which are quickly growing since first proposed by [@Cantor2004] and [@Yeh2004]. Contrary to most traditional alloys, they contain a large number of chemical elements (typically 4-9) in similar proportions, in hope to thermodynamically stabilize the material by increasing its configurational entropy ($\Delta S_{conf} = \Sigma_i^N x_i \ln{x_i}$ for ideal mixing of $N$ elements with fractions $x_i$), what encourages sampling a large palette of chemical elements. The resulting compositional spaces are both extremely vast and challenging to explore in terms of possible changes [@Krajewski2024Nimplex]; thus, it becomes critical to answer the question like *"Which combination of 15 elements out of 60 in the dataset will result in the largest dataset?"* which has $\binom{60}{15}$ or 53 trillion possible solutions.


# Methods and Performance

## Overview

![Schematic of core nimCSO data flow with a description of key methods. Metaprogramming is used to recompile the software optimized to the human-readable data and configuration files at hand.\label{fig:main}](assets/nimCSO_mainFigure.png){width="300pt"}



# Acknowledgements

This work has been funded through grants: **NSF-POSE FAIN-2229690**, **ONR N00014-23-2721**, and **DOE-ARPA-E DE-AR0001435**. 

We would also like to acknowledge Dr. Jonathan Siegel at Texas A&M University for valuable discussions and feedback on the project.


# References