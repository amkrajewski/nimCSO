# The MIT License (MIT)
# Copyright (C) 2023-2024 Adam M. Krajewski

# Pragmas with compiler and linker options
{.passC: "-flto -ffast-math".} 
{.passL: "-flto".} 

## .. importdoc::  nimcso/bitArrayAutoconfigured.nim
## 
## # Summary 
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
## `nimCSO` 

## This tool employs a set of methods, ranging from (1) brute-force search through (2) genetic algorithms to (3) a newly designed search method. They use custom data structures and procedures written in Nim language, which are compile-time optimized for the specific problem statement and dataset pair, which allows nimCSO to run faster and use 1-2 orders of magnitude less memory than general-purpose data structures. All configuration is done with a simple human-readable config file, allowing easy modification of the search method and its parameters.
## 
## 
## 
## 
## 
## 
## 
## 
## 
## 
## 
when defined(nimdoc):
    include ../benchmarks/docs

when defined(nimdoc):
    include ../tests/docs

# Standard library imports. One per line for easy change tracking.
import std/strutils
import std/sets
import std/times
import std/os
import std/sequtils
import std/random
import std/heapqueue
import std/hashes
import std/math
import std/algorithm
import std/terminal
import std/bitops

# Third-party library imports
import arraymancer/Tensor
import yaml

# NimCSO submodule imports
import nimcso/bitArrayAutoconfigured

# Import profiler only when needed
when compileOption("profiler"):
    import nimprof

# Define the config object to load from the YAML file
type Config = object
    taskName: string
    taskDescription: string
    elementOrder: seq[string]
    datasetPath: string

# Load config YAML file at the compile time (static block)
const
    configPath* {.strdefine.}: string = "config.yaml" ## **Compile-time-assigned** constant pointing to the specific ``config.yaml`` file used to compile the current ``nimCSO`` binary. It is exported to allow users to easily assert in scripts that they are using the correct config file.
    config = static:
        echo configPath
        var config: Config
        let s = readFile(configPath)
        load(s, config)
        config

    elementOrder* = config.elementOrder  ## **Compile-time-calculated** constant based on your speficic config/data files. Does not affect which elements are present in the results, but determines the order in which they are handled internally and printed in the results.
    elementN* = elementOrder.len  ## **Compile-time-calculated** constant based on your speficic config/data files. Allows us to optimize the data structures and relevant methods for the specific problem at the compile time.
    elementsPresentList = static:
        let elementSet = toHashSet(elementOrder)
        var result = newSeq[string]()
        for line in readFile(config.datasetPath).splitLines():
            var elements = initHashSet[string]()
            for e in line.split(","):
                elements.incl(e.strip())
            if elements <= elementSet:
                result.add(line)
        result
    alloyN* = elementsPresentList.len  ## **Compile-time-calculated** constant based on your speficic config/data files. Value is **config&dataset-dependent** and corresponds to the number of datapoints ingested from the dataset after filtering datapoints not contributing to the solution space (becasue of elements present in them.)
    
# Task name and description printout
styledEcho "Configured for task: ", styleBright, fgMagenta, styleItalic, config.taskName, resetStyle,
    styleDim, styleItalic, " (", config.taskDescription, ")", resetStyle

# ********* Dataset Ingestion *********

proc getPresenceTensor*(): Tensor[int8] =
    ## (Legacy function retained for easy Arraymancer integration for library users) Returns an Arraymancer ``Tensor[int8]`` denoting presence of elements in the dataset 
    ## (1 if present, 0 if not), which can be then used to calculate the quantity of data prevented by removal of a given set of elements. Operated based on compile-time constants.
    var
        presence = newTensor[int8]([alloyN, elementN])
        lineN: int = 0
        elN: int = 0

    for line in elementsPresentList:
        let elements = line.split(",")
        elN = 0
        for el in elementOrder:
            if elements.contains(el):
                presence[lineN, elN] = 1
            elN += 1
        lineN += 1
    return presence

proc getPresenceIntArray*(): array[alloyN, uint64] =
    ## Returns a compile-time-determined-length array of unsigned integers encoding the presence of elements in each row in the dataset, which is as fast and compact as you can get on a 
    ## 64-bit architecture. It is by far the most limiting representation implemented in ``nimCSO``, which **will not work for datasets with more than 64 elements**, but it is 
    ## **blazingly fast to access** and process, since we can leverage the hardware's native bit operations, and **uses a couple times less memory** than the ``BitArray`` representation 
    ## thanks to not having intermediate pointers, which for under 64 elements are the same size as the payload itself.
    var
        lineN: int = 0
        elN: int = 0

    for line in elementsPresentList:
        let elements = line.split(",")
        elN = 0
        for el in elementOrder:
            if elements.contains(el):
                result[lineN].setBit(elN)
            elN += 1
        lineN += 1

func getPresenceBitArrays*(): seq[BitArray] =
    ## Returns a sequence of ``BitArray``s encoding the presence of elements in each row in the dataset within _bits_ of integers stored in each BitArray. It operates based on 
    ## compile-time constants.
    var
        presence = BitArray()
        elN: int = 0

    for line in elementsPresentList:
        let elements = line.split(",")
        elN = 0
        for el in elementOrder:
            if elements.contains(el):
                presence[elN] = true
            elN += 1
        result.add(presence)
        presence = BitArray()

func getPresenceBoolArrays*(): seq[seq[bool]] =
    ## Returns a sequence of sequences of ``bool``s encoding the presence of elements in each row in the dataset. It is **faster than** ``getPresenceBitArrays`` but **uses more memory**,
    ## but only one instance is stored in the memory at a time, so it is a better choice for databases with less than many millions of rows. It operates based on compile-time constants.
    var
        elI: int = 0
        lineI: int = 0

    result = newSeqWith(alloyN, newSeq[bool](elementN))

    for line in elementsPresentList:
        let elements = line.split(",")
        elI = 0
        for el in elementOrder:
            if elements.contains(el):
                result[lineI][elI] = true
            elI += 1
        lineI += 1

# ********* Dataset-Solution Interactions *********

func preventedData*(elList: BitArray, presenceBitArrays: seq[BitArray]): int =
    ## Returns the number of datapoints prevented by removal of the elements encoded in the ``elList`` ``BitArray`` by comparing it to the sequence of ``BitArray``s encoding presence
    ## in the dataset.
    let elBoolArray: array[elementN, bool] = elList.toBoolArray

    func isPrevented(presenceBitArray: BitArray): bool =
        for i in 0..<elementN:
            if elBoolArray[i] and presenceBitArray.unsafeGet(i):
                return true
        return false
    for pm in presenceBitArrays:
        if isPrevented(pm):
            result += 1

func preventedData*(elList: BitArray, presenceBoolArrays: seq[seq[bool]]): int =
    ## Returns the number of datapoints prevented by removal of the elements encoded in the ``elList`` ``BitArray`` by comparing it to the sequence of sequences of ``bool``s encoding presence
    ## in the dataset. 
    let elBoolArray: array[elementN, bool] = elList.toBoolArray

    func isPrevented(presenceBoolArray: seq[bool]): bool =
        for i in 0..<elementN:
            if elBoolArray[i] and presenceBoolArray[i]:
                return true
        return false
    for pm in presenceBoolArrays:
        if isPrevented(pm):
            result += 1

func preventedData*(elList: uint64, presenceIntArray: array[alloyN, uint64]): int =
    ## Returns the number of datapoints prevented by removal of the elements encoded in the ``elList`` unsigned integer (``uint64``) by comparing it to the compile-time-determined-length array 
    ## of unsigned integers encoding the presence of elements in each row in the dataset. It **leverages the hardware's native bit operations** whenever possible, and is **blazingly fast** in 
    ## cases where it can be used.

    func isPrevented(presenceInt: uint64): bool =
        for i in 0..<elementN:
            if presenceInt.testBit(i) and elList.testBit(i):
                return true
        return false
    for i in presenceIntArray:
        if isPrevented(i):
            result += 1

proc preventedData*(elList: Tensor[int8], presenceTensor: Tensor[int8]): int =
    ## Returns the number of datapoints prevented by removal of the elements encoded in the ``elList`` 1D ``Tensor[int8]`` by comparing it to the 2D ``Tensor[int8]`` encoding presence
    ## in the dataset.
    let c = presenceTensor *. elList
    result = c.max(axis = 1).asType(int).sum()

func presentInData*(elList: BitArray, pBAs: seq[BitArray] | seq[seq[bool]]): int =
    ## A philosophical opposite of ``preventedData`` procedures. It returns the number of datapoints which have all of the elements encoded by the ``elList`` ``BitArray`` present in them,
    ## based on either a sequence of ``BitArray``s or a sequence of sequences of ``bool``s encoding presence in the dataset. For single element, it could be obtained by subtracting the 
    ## prevented data from the total data count, but it gets more complicated for multiple elements.
    let positionsPresent = elList.toSetPositions()

    func allPresent(presenceBitArray: BitArray): bool =
        for i in positionsPresent:
            if not presenceBitArray.unsafeGet(i):
                return false
        return true

    func allPresent(presenceBoolArray: seq[bool]): bool =
        for i in positionsPresent:
            if not presenceBoolArray[i]:
                return false
        return true

    for pm in pBAs:
        if allPresent(pm):
            result += 1


# ********* Elemental Solution Class Implementation *********

type ElSolution* = ref object
    ## The ``ElSolution`` object, or *Elemental Solution*, represents a singular solution to the problem of selecting elements to remove from the dataset. It is a reference object with two core fileds, 
    ## but is meant to be extended beyond that for advanced use cases (e.g., utilizing multi-property heuristics for the search algorithms). These two fields are:
    ## - ``elBA``: A [BitArray], configured at the compile time, holds the elements removed from the dataset in this solution. It can hold any number of elements. Its size is 64-bit aligned, so any
    ##   number of elements below 65 will not increase the memory usage.
    ## - ``prevented``: An ``int`` field, which holds the number of datapoints prevented from being considered due to the removal of the elements encoded in the ``elBA``. It is calculated when the
    ##   solution is created and can be recalculated with the ``setPrevented`` procedure.
    elBA*: BitArray
    prevented*: int

proc newElSolution*(elBA: BitArray,
                    pBA: seq[BitArray] | seq[seq[bool]]): ElSolution =
    ## Creates a new ``ElSolution`` object based on a ``BitArray`` encoding the presence of elements. It uses sequence of ``BitArray``s or a sequence of sequences of ``bool``s to calculate the
    ## number of prevented datapoints to set the ``prevented`` field.
    result = ElSolution()
    result.elBA = elBA
    result.prevented = preventedData(elBA, pBA)

proc newElSolution*(elementSet: seq[string],
                    pBA: seq[BitArray] | seq[seq[bool]]): ElSolution =
    ## Creates a new ``ElSolution`` object from a sequence of element name ``string``s, which it encodes into a ``BitArray`` based on the `elementOrder`_ defined in the config and passing 
    ## it to the other `newElSolution`_ procedure it overloads. In the process, it checks if the element set is a subset of the element order defined in the config.
    assert toHashSet(elementSet) <= toHashSet(elementOrder), "Element set is not a subset of the element order defined in the config."
    var elBA = BitArray()
    for i in 0..<elementN:
        if elementOrder[i] in elementSet:
            elBA[i] = true
    result = newElSolution(elBA, pBA)

proc newElSolutionRandomN*(order: int,
                           pBA: seq[BitArray] | seq[seq[bool]]): ElSolution =
    ## Creates a new ``ElSolution`` object with a random set of ``order`` number of elements present in it by randomly picking setting bits in initially unset ``BitArray`` until it reaches the
    ## desired number of bits set. It uses sequence of ``BitArray``s or a sequence of sequences of ``bool``s to calculate the number of prevented datapoints to set the ``prevented`` field.
    ## Primarily used in the `geneticSearch`_ algorithm, but could be used in other contexts as well.
    result = ElSolution(elBA: BitArray())
    while result.elBA.count < order:
        result.elBA[rand(elementN-1)] = true
    result.prevented = preventedData(result.elBA, pBA)

func hash*(elSol: ElSolution): Hash =
    ## Hashes the solution based on the hash of its ``BitArray`` only and not the number of prevented datapoints. Hashing is used for storage in ``HashSet``s and ``OrderedSet``s. The omission 
    ## of the number of prevented datapoints is intentional, as it allows checking for the presence of hypothetical solutions among the initialized (calculated) solutions without the need to 
    ## calculate presence.
    hash(elSol.elBA)

proc `$`*(elSol: ElSolution): string =
    ## Casts the solution into a string with human-readable list of elements present in it (in the order based on the config) pointing with ``->`` to the number of prevented datapoints.
    runnableExamples:
        let elSol = newElSolution(@["Cr", "Fe", "Ni"], getPresenceBitArrays())
        assert $elSol=="FeCrNi->1484"
    
    for i in 0..<elementN:
        if elSol.elBA[i]:
            result.add(elementOrder[i])
    result.add("->")
    result.add(elSol.prevented.intToStr())

func `<`*(a, b: ElSolution): bool = 
    ## Compares two ``ElSolution``s based on the number of prevented datapoints. Used for sorting and comparison in the search algorithms.
    a.prevented < b.prevented 

func `>`*(a, b: ElSolution): bool = 
    ## Compares two ``ElSolution``s based on the number of prevented datapoints. Used for sorting and comparison in the search algorithms.
    a.prevented > b.prevented

proc `==`*(a, b: ElSolution): bool = 
    ## Checks equality of two ``ElSolution``s based on the equality of their [BitArray]s. Please note this is *not* the same as ``>`` and ``<`` operators, which are based on the number of prevented datapoints.
    a.elBA == b.elBA

func setPrevented*(elSol: var ElSolution,
                   presenceArrays: seq[BitArray] | seq[seq[bool]]): void =
    ## Calculates and sets the ``prevented`` field of the ``var ElSolution`` based on the presence of elements in the dataset encoded in either a sequence of ``BitArray``s or a sequence of sequences of ``bool``s.
    elSol.prevented = preventedData(elSol.elBA, presenceArrays)

proc randomize*(elSol: var ElSolution): void =
    ## Randomizes the ``BitArray`` of the ``var ElSolution`` by setting each bit to a random value, used primarily for benchmarking purposes.
    for i in 0..<elementN:
        elSol.elBA[i] = (rand(1) > 0)


# ********* Genetic Algorithm Procedures *********

proc mutate*(elSol: var ElSolution, presenceArrays: seq[BitArray] | seq[seq[bool]]): void =
    ## Mutates the ``var ElSolution`` by taking its ``BitArray`` and swapping at random two of its bits from the range encoding presence of elements in the dataset. It then recalculates the number of 
    ## prevented datapoints based on the presence of elements in the dataset encoded in either a sequence of ``BitArray``s or a sequence of sequences of ``bool``s.
    ## 
    ## .. image:: ../paper/assets/nimcso_mutate_wide.drawio.png
    ##    :alt: nimCSO Mutation
    ## 
    ## As depicted in the diagram, the mutation procedure is fully random so (1) bit can swap itself, (2) bits can swap causing a flip, or (3) bits can swap with no effect.
    let
        i = rand(elementN-1)
        j = rand(elementN-1)
    let temp = elSol.elBA[i]
    elSol.elBA[i] = elSol.elBA[j]
    elSol.elBA[j] = temp
    elSol.setPrevented(presenceArrays)

proc crossover*(elSol1: var ElSolution, elSol2: var ElSolution,
                presenceArrays: seq[BitArray] | seq[seq[bool]]): void =
    ## Implementation of the crossover here is more elaborate than typical swapping you may see elswere due to constraint of conservation of the number of set bits in the output solutions, so
    ## that they retain the same order. The proceducre takes two ``var ElSolution``s and:
    ## 1. Finds positions of non-overlapping bits, while not modifying the overlapping ones.
    ## 2. Randomizes the order of non-overlapping positions set.
    ## 3. Sets the bits in the output solutions by picking from the randomized set of non-overlapping positions.
    ## 
    ## .. image:: ../paper/assets/nimcso_crosslink.drawio.png
    ##    :alt: nimCSO Crossover
    ## 
    ## It is primarily used in the `geneticSearch`_ algorithm.
    var
        setElements: seq[int] = elSol1.elBA.toSetPositions
        elBA1 = BitArray()
        elBA2 = BitArray()
    for i in elSol2.elBA.toSetPositions:
        if setElements.contains(i):
            setElements.del(setElements.find(i))
            elBA1[i] = true
            elBA2[i] = true
        else:
            setElements.add(i)
    setElements.shuffle()
    while true:
        if setElements.len == 0:
            break
        elBA1[setElements.pop()] = true
        if setElements.len == 0:
            break
        elBA2[setElements.pop()] = true
    elSol1.elBA = elBA1
    elSol2.elBA = elBA2
    elSol1.setPrevented(presenceArrays)
    elSol2.setPrevented(presenceArrays)


# ********* Exploration-Related Procedures Shared by All Search Methods *********

func getNextNodes*(elSol: ElSolution,
                   exclusions: BitArray,
                   presenceBitArrays: seq[BitArray] | seq[seq[bool]]): seq[ElSolution] =
    ## Takes the current [ElSolution] and compares it with ``exclusions`` ``BitArray`` to determine all possible next steps (removing additional element from dataset) that do not 
    ## overlap with the exclusions. Used primarily in the `algorithmSearch`_ routine to explore the solution space without visiting the same solution twice. Performance can be tested
    ## with the `expBenchmark`_ routine.
    for i in 0..<elementN:
        if not elSol.elBA[i] and not exclusions[i]:
            var newElBA: BitArray
            newElBA = elSol.elBA
            newElBA[i] = true
            result.add(newElSolution(newElBA, presenceBitArrays))

# ********* Results Persistence *********

proc saveResults*(
        results: seq[ElSolution], 
        path: string = "results.csv", 
        separator: string = "-"
        ): void =
    ## Saves results from any routine (stored in a sequence of [ElSolution]s) into to a CSV file with columns "Removed Elements", "Allowed Elements", "Prevented", "Allowed", into a file
    ## at the ``path``. The ``separator`` is used to separate the element names, and it is set to a dash ``-`` by default resulting in easily readable strig (e.g., ``Cr-Fe-Ni-Mo``).
    var f = open(path, fmWrite)
    f.writeLine("Removed Elements, Allowed Elements, Prevented, Allowed")
    for elSol in results:
        var 
            elList1 = newSeq[string]()
            elList2 = newSeq[string]()
        for i in 0..<elementN:
            if elSol.elBA[i]:
                elList1.add(elementOrder[i])
            else:
                elList2.add(elementOrder[i])
        let
            prevented = elSol.prevented
            allowed = alloyN - prevented
        f.write(elList1.join(separator), ", ", elList2.join(separator), ", ", prevented.intToStr(), ", ", allowed.intToStr(), "\n")
    f.close()

proc saveFilteredDataset*(path: string = "filteredDataset.csv"): void = 
    ## Saves the filtered dataset (containing only the datapoints contributing to the solution space as defined by set of ``elementOrder``) into a file at the ``path``.
    var f = open(path, fmWrite)
    for line in elementsPresentList:
        f.writeLine(line)
    f.close()

# ********* Helper Procedures *********

template benchmark(benchmarkName: string, verbose: bool, code: untyped) =
    block:
        let t0 = epochTime()
        for i in 1..10000:
            code
        let elapsed = (epochTime() - t0) * 100
        let elapsedStr = elapsed.formatFloat(format = ffDecimal, precision = 1)
        if verbose: 
            styledEcho "CPU Time [", benchmarkName, "] ", styleBright, fgGreen, elapsedStr, "μs", resetStyle

template benchmarkOnce(benchmarkName: string, verbose: bool, code: untyped) =
    block:
        let t0 = epochTime()
        code
        let elapsed = (epochTime() - t0) * 1000
        let elapsedStr = elapsed.formatFloat(format = ffDecimal, precision = 1)
        if verbose: 
            styledEcho "CPU Time [", benchmarkName, "] ", styleBright, fgGreen, elapsedStr, "ms", resetStyle

template timeEstimate(iterN: int, verbose: bool, code: untyped) =
    block:
        let t0 = epochTime()
        for i in 1..1000:
            code
        let t1 = epochTime() - t0
        if verbose:
            styledEcho "Task ETA Estimate: ", styleBright, fgMagenta, $initDuration(milliseconds = (t1 * iterN.float).int), resetStyle


proc echoHelp() = echo """
To use form command line, provide parameters. Currently supported usage:

--covBenchmark    | -cb   --> Run small coverage benchmarks under two implementations.
--expBenchmark    | -eb   --> Run small node expansion benchmarks.
--leastPreventing | -lp   --> Run a search for single-elements preventing the least data, i.e. the least common elements.
--mostCommon      | -mc   --> Run a search for most common elements.
--bruteForce      | -bf   --> Run brute force algorithm after getting ETA. Note that it is not feasible for more than 25ish elements.
--bruteForceInt   | -bfi  --> Run brute force algorithm with faster but not extensible uint64 representation after getting ETA. Up to 64 elements only.
--geneticSearch   | -gs   --> Run a genetic search algorithm.
--algorithmSearch | -as   --> Run a custom problem-informed best-first search algorithm.
--develpment      | -d    --> DEPRECATED: Run development code.

"""

# ********* Core Routines *********

proc covBenchmark() =
    ## Runs "coverage" benchmarks testing and cross-method consistecy check. For each method, it creates 1,000 random solution candidates of any order, and then calculates the 
    ## number of prevented datapoints for each of them. For the consistency check, it removes (sets) the first 5 elements and calculates the number of prevented datapoints for the
    ## resulting solution. The results are printed to the console.
    block:
        styledEcho fgBlue, "Running coverage benchmark with int8 Tensor representation", resetStyle

        let presenceTensor = getPresenceTensor()
        var b = zeros[int8](shape = [1, elementN])
        b[0, 0..5] = 1
        echo b

        benchmark "arraymancer+randomizing", verbose=true:
            discard preventedData(randomTensor[int8](shape = [1, elementN], sample_source = [0.int8, 1.int8]),
                                    presenceTensor)
        echo "Prevented count:", preventedData(b, presenceTensor)

    block:
        styledEcho fgBlue, "\nRunning coverage benchmark with BitArray representation"
        let presenceBitArrays = getPresenceBitArrays()

        benchmark "bitty+randomizing", verbose=true:
            var esTemp = ElSolution()
            esTemp.randomize()
            esTemp.setPrevented(presenceBitArrays)

        var bb = BitArray()
        for i in 0..5: bb[i] = true
        styledEchoAnnotated bb
        let particularResult = newElSolution(bb, presenceBitArrays)
        echo particularResult
        echo "Prevented count:", particularResult.prevented

    block:
        styledEcho fgBlue, "\nRunning coverage benchmark with bool arrays representation (BitArray graph retained)", resetStyle
        let presenceBoolArrays = getPresenceBoolArrays()
        benchmark "bit&boolArrays+randomizing", verbose=true:
            var esTemp = ElSolution()
            esTemp.randomize()
            esTemp.setPrevented(presenceBoolArrays)

        var bb = BitArray()
        for i in 0..5: bb[i] = true
        styledEchoAnnotated bb
        let particularResult = newElSolution(bb, presenceBoolArrays)
        echo particularResult
        echo "Prevented count:", particularResult.prevented

proc expBenchmark() =
    ## Runs "expansion" benchmarks testing and cross-method consistecy check. For both ``seq[bool]`` and ``BitArray`` representations, it check how fast they can (1) expand one step from 
    ## the initial solution (i.e. elementN expansions), (2) expand one step from a random solution (avg. 1/2 elementN expansions), and (3) expand up to 1,000 steps from the initial solution.
    ## The results are printed to the console. 
    block:
        styledEcho fgBlue, "\nRunning coverage benchmark with BitArray representation:", resetStyle
        let
            bb = BitArray()
            presenceBitArrays = getPresenceBitArrays()

        var esTemp = newElSolution(bb, presenceBitArrays)
        echo esTemp.getNextNodes(BitArray(), presenceBitArrays)
        benchmark "Expanding to elementN nodes 1000 times from empty", verbose=true:
            discard esTemp.getNextNodes(bb, presenceBitArrays)

        benchmark "Expanding to 1000 times from random", verbose=true:
            esTemp.randomize()
            discard esTemp.getNextNodes(bb, presenceBitArrays)

        var
            solutions = initHeapQueue[ElSolution]()
            toExpand: ElSolution
            toExclude = BitArray()
    
        solutions.push(newElSolution(BitArray(), presenceBitArrays))
        benchmark "Expanding 1000 steps (results dataset-dependent!)", verbose=true:
            toExpand = solutions.pop()
            for sol in getNextNodes(toExpand, toExclude, presenceBitArrays):
                solutions.push(sol)
            toExclude = toExclude or toExpand.elBA
            if len(solutions) == 1:
                echo "\n******  Test completed too fast -> the solution tree exhausted before 1000 steps.  ******"
                break
        echo "Last solution on heap: ", solutions[0]

    block:
        styledEcho fgBlue, "\nRunning coverage benchmark with bool arrays representation (BitArray graph retained)", resetStyle
        let bb = BitArray()
        let presenceBoolArrays = getPresenceBoolArrays()
        var esTemp = newElSolution(bb, presenceBoolArrays)

        benchmark "Expanding to elementN nodes 1000 times from empty", verbose=true:
            discard esTemp.getNextNodes(bb, presenceBoolArrays)

        benchmark "Expanding to 1000 times from random", verbose=true:
            esTemp.randomize()
            discard esTemp.getNextNodes(bb, presenceBoolArrays)

        var
            solutions = initHeapQueue[ElSolution]()
            toExpand: ElSolution
            toExclude = BitArray()
        solutions.push(newElSolution(BitArray(), presenceBoolArrays))
        benchmark "Expanding 1000 steps (results dataset-dependent!)", verbose=true:
            toExpand = solutions.pop()
            for sol in getNextNodes(toExpand, toExclude, presenceBoolArrays):
                solutions.push(sol)
            toExclude = toExclude or toExpand.elBA
            if len(solutions) == 1:
                echo "\n******  Test completed too fast -> the solution tree exhausted before 1000 steps.  ******"
                break
        echo "Last solution on heap: ", solutions[0]

proc leastPreventing*(verbose: bool = true): seq[ElSolution] =
    ## Runs a search for single-element solutions preventing the least data, i.e. the least common elements *based on the filtered dataset*. Returns a sequence of [ElSolution]s which can
    ## be used on its own (by setting ``verbose`` to see it or by using ``saveResults``) or as a starting point for an exploration technique.
    let presenceBitArrays = getPresenceBitArrays()
    benchmarkOnce "Searching for element removals preventing the least data:", verbose:
        var solutions = initHeapQueue[ElSolution]()
        for i in 0..<elementN:
            var elSol = ElSolution()
            elSol.elBA[i] = true
            elSol.setPrevented(presenceBitArrays)
            solutions.push(elSol)
        for i in 0..<elementN:
            let sol = solutions.pop()
            if verbose: echo sol
            result.add(sol)

proc mostCommon*(verbose: bool = true): seq[ElSolution] =
    ## Convenience wrapper for the ``leastPreventing`` routine, which returns its results in reversed order. It was added for the sake of clarity.
    let lpSol = leastPreventing(false).reversed()
    if verbose:
        for sol in lpSol: echo sol
    result = lpSol


proc algorithmSearch*(verbose: bool = true): seq[ElSolution] =
    ## **(Key Routine)** This custom algorithm iteratively expands and evaluates candidates from a priority queue (binary heap), while leveraging `the fact` that the number of data points lost when 
    ## removing elements `A` and `B` from the dataset has to be at least as large as when removing either `A` or `B` alone to delay exploration of candidates until they can contribute 
    ## to the solution. Furthermore, to (1) avoid revisiting the same candidate without keeping track of visited states and (2) further inhibit the exploration of unlikely candidates, 
    ## the algorithm `assumes` that while searching for a given order of solution, elements present in already expanded solutions will not improve those not yet expanded. This 
    ## effectively prunes candidate branches requiring two or more levels of backtracking. This method has generated the same results as combinatoric brute forcing in our tests, as 
    ## demonstrated in the ``tests/algorithmSearch`` script, except for occasional differences in the last explored solution. By default, the [BitArray] representation is used, but
    ## the ``bool`` array representation can be used by setting the ``presenceArrays`` parameter to ``getPresenceBoolArrays()``.
    
    if verbose: styledEcho "\nRunning Algorithm Search for ", styleBright, fgMagenta, $elementN, resetStyle, " elements."
    let presenceBitArrays = getPresenceBitArrays()
    var solutions = initHeapQueue[ElSolution]()

    benchmarkOnce "exploring", verbose:
        solutions.push(newElSolution(BitArray(), presenceBitArrays))
        var toExpand: ElSolution
        # Iterate over all solution orders
        for order in 1..<elementN:
            var toExclude = BitArray()
            var topSolutionOrder: int = 0
            while true:
                toExpand = solutions.pop()
                for sol in getNextNodes(toExpand, toExclude, presenceBitArrays):
                    solutions.push(sol)
                toExclude = toExclude or toExpand.elBA
                topSolutionOrder = count(solutions[0].elBA)
                if topSolutionOrder >= order:
                    break

            if verbose: 
                styledEcho styleBright, fgBlue, ($order).align(2), ": ", resetStyle, fgGreen, $solutions[0], styleDim, fgBlack, "  (tree size: ", $len(solutions), ")", resetStyle
            result.add(solutions[0])


proc bruteForce*(verbose: bool = true): seq[ElSolution] =
    ## **(Key Routine)** A **high performance** (35 times faster than native Python and 4 times faster than NumPy) and **easily extensible** (leveraging the [ElSolution] type) brute force algorithm for finding 
    ## the optimal solution for the problem of which N elements to remove from dataset to loose the least daya. It enumerates all entries in the `power set` of considered elements by representing them as integers 
    ## from ``0`` to ``2^elementN - 1`` and using them to initialize ``BitArray``s. It then iteratively evaluates them keeping track of the best solution for each order (number of elements present in the solution), what 
    ## allows for a **minimal memory footprint** as only several solutions are kept in memory at a time. The results are printed to the console. It is implemented for up to 64 elements,
    ## as it is not feasible for more than around 30 elements, but it could be extended by simply enumerating solutions as two or more integers and using them to initialize ``BitArray``s.
    assert elementN <= 64, "Brute Force is not feasible for more than around 30 elements, thus it is not implemented for above 64 elements."
    if verbose: styledEcho "\nRunning Brute Force search for ", styleBright, fgMagenta, $elementN, resetStyle, " elements."
    let presenceBitArrays = getPresenceBitArrays()
    const solutionN = 2^elementN - 1
    if verbose: styledEcho "Solution space size: ", styleBright, fgMagenta, $solutionN, resetStyle

    timeEstimate solutionN, verbose:
        let elBA = BitArray(bits: [1])
        discard newElSolution(elBA, presenceBitArrays)
        discard elBA.count

    const solutionRange = 0.uint64..solutionN.uint64
    benchmarkOnce "Brute Force", verbose:
        var topSolutions: array[elementN+1, ElSolution]
        # Initlialize with with highes possible prevented value (in contrast to the desfault 0)
        for i in 0..elementN: topSolutions[i] = ElSolution(prevented: int.high)
        for c in solutionRange:
            let elBA = BitArray(bits: [c])
            let elSol = newElSolution(elBA, presenceBitArrays)
            let order = elBA.count
            if topSolutions[order] > elSol:
                topSolutions[order] = elSol
            
        for i in 0..elementN:
            let sol = topSolutions[i]
            result.add(sol)
            if verbose: 
                styledEcho styleBright, fgBlue, ($i).align(2), ": ", resetStyle, fgGreen, $sol, resetStyle

proc bruteForceInt*(verbose: bool = true): seq[ElSolution] =
    ## **(Key Routine)** A **really high performance** (400 times faster than native Python and 50 times faster than NumPy) brute force algorithm for finding the optimal solution for the problem of which 
    ## N elements to remove from dataset to loose the least daya. Unlike the standard `bruteForce`_ algorithm does not use the `ElSolution`_ type and **cannot be easily extended** to other use cases and 
    ## **cannot be used for more than 64 elements** without sacrificing the performance, at which point `bruteForce`_ should be much better choice.
    assert elementN <= 64, "Brute Force with uint64 representation cannot run on more than 64 elements. You will need to take `bruteForce` instead and implement it for more than 64 elements."
    if verbose: styledEcho "\nRunning brute force algorithm for ", styleBright, fgMagenta, $elementN, resetStyle, " elements."
    let presenceInts = getPresenceIntArray()
    let presenceBitArrays = getPresenceBitArrays()
    const solutionN = 2^elementN - 1
    if verbose: styledEcho "Solution space size: ", styleBright, fgMagenta, $solutionN, resetStyle

    timeEstimate solutionN, verbose:
        let i = 1.uint64
        discard preventedData(i, presenceInts)
        discard i.countSetBits

    const solutionRange = 0.uint64..solutionN.uint64
    benchmarkOnce "Brute Force", verbose:
        var topSolutionsScore: array[elementN+1, int]
        # Initlialize with with highes possible prevented value (in contrast to the desfault 0)
        for i in 0..elementN: 
            topSolutionsScore[i] = int.high
        var topSolutions: array[elementN+1, ElSolution]
        for c in solutionRange:
            let order = c.countSetBits
            let prevented = preventedData(c, presenceInts)
            if topSolutionsScore[order] > prevented:
                topSolutionsScore[order] = prevented
                topSolutions[order] = newElSolution(BitArray(bits: [c]), presenceBitArrays)

        for i in 0..elementN:
            let sol = topSolutions[i]
            result.add(sol)
            if verbose: 
                styledEcho styleBright, fgBlue, ($i).align(2), ": ", resetStyle, fgGreen, $sol, resetStyle


proc geneticSearch*(
        verbose: bool = true,
        initialSolutionsN: Natural = 100,
        searchWidth: Natural = 100,
        maxIterations: Natural = 1000,
        minIterations: Natural = 10,
        mutationsN: Natural = 1
        ): seq[ElSolution] =
    ## **(Key Routine)** This custom genetic algotithm utilizes custom [mutate]_ and [crossover]_ procedures preserving the number of elements present (bits set) in their output solutions to
    ## iteratively improve a set of solutions. It is primarily aimed at (1) problems with more than 40 elements, where neither `bruteForce`_ nor `algorithmSearch`_ are feasible and (2) at 
    ## cases where the decent solution is needed quickly. Its implementation **allows for arbitrary dimensionality** of the problem and its time complexity will scale linearly with it. You may
    ## control a set of parameters to adjust the algorithm to your needs, including the number of initial randomly generated solutions ``initialSolutionsN``, the number of solutions to keep 
    ## carry over to the next iteration ``searchWidth``, the maximum number of iterations ``maxIterations``, the minimum number of iterations the solution has to fail to improve to be 
    ## considered.
    let presenceBitArrays = getPresenceBitArrays()

    benchmarkOnce "Genetic Search", verbose:
        var solutions = initHeapQueue[ElSolution]()
        # The first solution does not need any expansions
        for sol in getNextNodes(ElSolution(), BitArray(), presenceBitArrays):
            solutions.push(sol)
        if verbose: 
            styledEcho styleBright, fgBlue, " 1: ", resetStyle, fgGreen, $solutions[0], resetStyle
        result.add(solutions[0])

        for order in 2..<elementN:
            solutions = initHeapQueue[ElSolution]()

            # Initialize with random initialSolutionsN solutions
            for i in 1..initialSolutionsN:
                solutions.push(newElSolutionRandomN(order, presenceBitArrays))

            # Iterate UP TO maxIterations times (until converged)
            var bestValuesSeq = @[solutions[0].prevented]
            for i in 0..<maxIterations:
                var
                    topNset = initOrderedSet[ElSolution]()
                    newSolutions = initOrderedSet[ElSolution]()

                # Acquire top solutions
                let topSolution = solutions.pop()
                bestValuesSeq.add(topSolution.prevented)
                topNset.incl(topSolution)
                while len(topNset) < searchWidth and len(solutions) > 0:
                    topNset.incl(solutions.pop())
                let topNseq = topNset.toSeq

                # Generate new solutions through mutations. Retain the original solutions as well.
                for sol in topNseq:
                    var tempSol = ElSolution(elBA: sol.elBA)
                    for j in 1..mutationsN:
                        tempSol.mutate(presenceBitArrays)
                    newSolutions.incl(sol)
                    newSolutions.incl(tempSol)

                # Generate new solutions through crossovers. Does not retain the original solutions. If the number of solutions is odd, the last one is not used.
                for i in countup(1, len(topNseq)-1, 2):
                    var tempSol1 = ElSolution(elBA: topNseq[i-1].elBA)
                    var tempSol2 = ElSolution(elBA: topNseq[i].elBA)
                    crossover(tempSol1, tempSol2, presenceBitArrays)
                    newSolutions.incl(tempSol1)
                    newSolutions.incl(tempSol2)

                # Push new solutions to queue
                for sol in newSolutions:
                    solutions.push(sol)

                # Check if converged after minIterations have passed. The convergence is defined as the same best value as 10 iterations ago.
                if i > minIterations:
                    if bestValuesSeq[^10] == bestValuesSeq[^1]:
                        break

            if verbose: 
                styledEcho styleBright, fgBlue, ($order).align(2), ": ", resetStyle, fgGreen, $solutions[0], styleDim, fgBlack, "  (queue size: ", $len(solutions), ")", resetStyle
            result.add(solutions[0])


# ********* Main Routine for Command Line Interface *********

when isMainModule:
    styledEcho fgGreen, "***** nimCSO (Composition Space Optimization) *****", resetStyle
    let args = commandLineParams()
    if args.len == 0:
        echoHelp()
        quit 0

    if "--help" in args or "-h" in args:
        echoHelp()
        quit 0

    if "--covBenchmark" in args or "-cb" in args:
        covBenchmark()

    if "--expBenchmark" in args or "-eb" in args:
        expBenchmark()

    if "--development" in args or "-d" in args or "--algorithmSearch" in args or "-as" in args:
        if "--development" in args or "-d" in args:
            echo "DEPRECATED and will be removed in the future. Please use --algorithmSearch instead."
        discard algorithmSearch(verbose=true)

    if "--bruteForce" in args or "-bf" in args:
        discard bruteForce(verbose=true)

    if "--bruteForceInt" in args or "-bfi" in args:
        discard bruteForceInt(verbose=true)

    if "--geneticSearch" in args or "-gs" in args:
        discard geneticSearch(verbose=true)

    if "--leastPreventing" in args or "-lp" in args:
        discard leastPreventing(verbose=true)

    if "--mostCommon" in args or "-mc" in args:
        discard mostCommon(verbose=true)

    styledEcho fgGreen, styleBright, "\nnimCSO Done!", resetStyle





