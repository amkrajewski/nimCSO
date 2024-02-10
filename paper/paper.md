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
  - name: Zi-Kui Liu
    orcid: 0000-0003-3346-3696
    affiliation: 1
affiliations:
 - name: Department of Materials Science and Engineering, The Pennsylvania State University, USA
   index: 1
date: 14 September 2023
#bibliography: [paper/paper.bib]
bibliography: paper.bib
---


# Summary

`nimCSO` is a high-performance, low-level tool for selecting components (dimensions) in compositional spaces which optimize the data availability for applications such as machine learning, which is a combinatorically hard problem for complex compositions existing in highly dimensional spaces due to the interdependency of components being present. Such spaces are often encountered in materials science, where datasets on Compositionally Complex Materials (CCMs) often span 20-40 chemical elements, while each data point contains several of them.

This tool employs a set of methods, ranging from (1) brute-force search through (2) genetic algorithms to (3) a newly designed search method. They use custom data structures and procedures written in Nim language, which are compile-time optimized for the specific problem statement and dataset pair, which allows nimCSO to run faster and use 1-2 orders of magnitude less memory than general-purpose data structures. All configuration is done with a simple human-readable config file, allowing easy modification of the search method and its parameters.


# Statement of Need

The Compositionally Complex Materials (CCMs), and their matal-focused subset of High Entropy Alloys (HEAs), belong to a rapidly emerging class of materials, first proposed by [@Cantor2004] and [@Yeh2004]. Contrary to more traditional materials, they contain a large number of chemical elements, typically 4-9 in similar proportions, in hope to thermodynamically stabilize the material by increasing its configurational entropy, by up to $\Delta S_{conf} = \Sigma_i^N x_i \ln{x_i}$ for ideally random mixing of $N$ elements with fractions $x_i$. 


# Methods and Performance

Methods and Performance

# Acknowledgements

Acknowledge:
- Jonathan Siegel at TAMU


# References