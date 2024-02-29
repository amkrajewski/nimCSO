
## **Navigation:** [nimCSO](nimcso.html) (core library) | [Changelog](docs/changelog.html) | [nimcso/bitArrayAutoconfigured](nimcso/bitArrayAutoconfigured.html)

## **nim** **C**omposition **S**pace **O**ptimization is a high-performance tool implementing several methods for selecting components (data dimensions) in compositional datasets, which 
## optimize the data availability and density for applications such as machine learning (ML) given a constraint on the number of components to be selected. Ability to do so is crucial for 
## deploying machine learning (ML) algorithms, so that they can be designed in a way balancing their accuracy and domain of applicability. Making said choice is a combinatorically hard 
## problem when data is composed of a large number of independent components due to the interdependency of components being present. Thus, efficiency of the search becomes critical for any
## application where interaction between components is of interest in a modeling effort, ranging:
## - from market **economics**,
## - through **medicine** where drug interactions can have a significant impact on the treatment, 
## - to **materials science**, where the composition and processing history are critical to resulting properties.
## 
## We are particularily interested in the latter case of materials science, where we utilize `nimCSO` to optimize ML deployment over our datasets on Compositionally Complex Materials (CCMs) 
## which are largest ever collected (from almost 550 publications) spanning up to 60 dimensions and developed within the [**ULTERA Project (ultera.org)**](https://ultera.org) carried under the 
## [**US DOE ARPA-E ULTIMATE**](https://arpa-e.energy.gov/?q=arpa-e-programs/ultimate) program which aims to develop 
## a new generation of ultra-high temperature materials for aerospace applications, through generative machine learning models [10.20517/jmi.2021.05](https://doi.org/10.20517/jmi.2021.05)
## driving thermodynamic modeling and experimentation [10.2139/ssrn.4689687](https://dx.doi.org/10.2139/ssrn.4689687).
## 
## At its core, `nimCSO` leverages the **metaprogramming** ability of the [Nim language](https://nim-lang.org) to optimize itself at the compile time, both in terms of speed and memory handling, 
## to the specific problem statement and dataset at hand based on a human-readable configuration file. As demonstrated later in benchamrks, `nimCSO` reaches the physical limits of the hardware 
## (L1 cache latency) and can outperform an efficient native Python implementation over 400 times in terms of speed and 50 times in terms of memory usage (*not* counting interpreter), while 
## also outperforming NumPy implementation 35 and 17 times, respectively, when checking a candidate solution.
## 
## .. figure:: assets/nimCSO_mainFigure.png
##   :alt: Main nimCSO figure
## 
## `nimCSO` is designed to be both (1) a user-ready tool (see figure above), implementing:
## - **Efficient brute force approaches** (for handling up to 25 dimensions)
## - **Custom search algorithm** (for up to 40 dimensions)
## - **Genetic algorithm** (for any dimensionality)
## , and also is (2) a scaffold for building even more elaborate methods in the future, including heuristics going beyond  data availability. All configuration is done with a simple 
## human-readable `YAML` config file and plain text data files, making it easy to modify the search method and its parameters with 
## no knowledge of programming and only basic command line skills. A single command is used to recompile (`nim c -f`) and run (`-r`) problem (`-d:configPath=config.yaml`) with `nimCSO` 
## (`src/nimcso`) using one of several methods. Advanced users can also quickly customize the provided methods with brief scripts using the `nimCSO` as a data-centric library.
 

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
## ## Elemental Solutions
## Throughout this codebase and documentation, you will see ``ElSolution``, which is a short for "Elemental Solution" and represents a solution to the problem of selecting elements
## to remove from the dataset. Using word *elements* is not technically precise, as the solution space is built around *components*, which do not have to be elemental entities in your problem, 
## and you can model compositions of any kind. However, in the code we consistently refer to "elements" because (1) it is the most common use case and (2) ``elSol`` obviously sounds much better 
## than ``comSol``.
## 
## 