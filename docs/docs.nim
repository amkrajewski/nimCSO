
## **Navigation:** [nimCSO](nimcso.html) (core library) | [Changelog](docs/changelog.html) | [nimcso/bitArrayAutoconfigured](nimcso/bitArrayAutoconfigured.html)
## 
## **nim** **C**omposition **S**pace **O**ptimization is a high-performance, low-level tool for selecting sets of components (dimensions) in compositional spaces, which optimize the data availability 
## given a constraint on the number of components to be selected. Ability to do so is crucial for deploying machine learning (ML) algorithms, so that they can be designed in a way balancing their
## accuracy and domain of applicability. Howerver, this becomes a combinatorically hard problem for complex compositions existing in highly dimensional spaces due to the interdependency of components 
## being present. For instance, removing datapoints many low-frequency components 
## 
## 
## 
## Such spaces are often encountered in materials science, where datasets on Compositionally Complex Materials (CCMs) often span 20-40 chemical elements, while each data point contains 
## several of them.
## 
## 
## 
## 
## This tool employs a set of methods, ranging from (1) brute-force search through (2) genetic algorithms to (3) a newly designed search method. They use custom data structures and procedures written in Nim language, which are compile-time optimized for the specific problem statement and dataset pair, which allows nimCSO to run faster and use 1-2 orders of magnitude less memory than general-purpose data structures. All configuration is done with a simple human-readable config file, allowing easy modification of the search method and its parameters.
## 
## 
## # Usage
## 
## 
## ## config.yaml
## The `config.yaml` file is the critical component which defines several required parameters listed below.
## - **taskName** - A ``string`` with the name of the task. It does *not* affect the results in any way, except for being printed during runtime for easier identification.
## - **taskDescription** - A ``string`` with the description of the task. It does *not* affect the results in any way, except for being printed during runtime for easier identification.
## - **datasetPath** - A ``string`` with the path (relative to CWD) with the dataset file. Please see `Dataset files`_ below for details on its content.
## - **elementOrder** - A list of ``string``s with the names of the elements in the dataset
## 
## ## Dataset files
## 
## The dataset file should contain one set of elements per line separated by commas. The order of rows and "columns" does not matter. The dataset can contain any elements, 
## as the one not present in the ``elementOrder`` will be ignored. The dataset should *not* contain any header.
## 
## 
## 
## # Notes:
## ## ElSolution
## Throughout this codebase and documentation, you will see ``ElSolution``, which is a short for "Elemental Solution", which represents a solution to the problem of selecting elements
## to remove from the dataset. This is not technically precise, as the solution space is built around components, which do not have to be elements, and you can define your problem around
## compositions of any kind. However, here we consistently refer to "elements" because (1) it is the most common use case and (2) ``elSol`` sounds much better than ``comSol``.
## 
## 