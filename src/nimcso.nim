# The MIT License (MIT)
# Copyright (C) 2023 Adam M. Krajewski

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
when defined(nimdoc):
    include ../tests/docs

runnableExamples:
    let presenceTensor = getPresenceTensor()

# Standard library imports. One per line for easy change tracking.
import std/strutils
import std/sets
import std/sugar
import std/times
import std/os
import std/sequtils
import std/random
import std/heapqueue
import std/hashes
import std/math
import std/algorithm
import std/terminal

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
    configPath {.strdefine.}: string = "config.yaml"
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
            let elements = toHashSet(line.split(",").map(el => el.strip()))
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
    var f = open(path, fmWrite)
    for line in elementsPresentList:
        f.writeLine(line)
    f.close()

# ********* Helper Procedures *********

template benchmark(benchmarkName: string, verbose: bool, code: untyped) =
    block:
        let t0 = epochTime()
        for i in 1..1000:
            code
        let elapsed = (epochTime() - t0) * 1000
        let elapsedStr = elapsed.formatFloat(format = ffDecimal, precision = 1)
        if verbose: echo "CPU Time [", benchmarkName, "] ", elapsedStr, "us"

template benchmarkOnce(benchmarkName: string, verbose: bool, code: untyped) =
    block:
        let t0 = epochTime()
        code
        let elapsed = (epochTime() - t0) * 1000
        let elapsedStr = elapsed.formatFloat(format = ffDecimal, precision = 1)
        if verbose: echo "CPU Time [", benchmarkName, "] ", elapsedStr, "ms"

template timeEstimate(iterN: int, code: untyped) =
    block:
        let t0 = epochTime()
        for i in 1..1000:
            code
        let t1 = epochTime() - t0
        styledEcho "Task ETA Estimate: ", styleBright, fgMagenta, $initDuration(milliseconds = (t1 * iterN.float).int), resetStyle


proc echoHelp() = echo """
To use form command line, provide parameters. Currently supported usage:

--covBenchmark    | -cb   --> Run small coverage benchmarks under two implementations.
--expBenchmark    | -eb   --> Run small node expansion benchmarks.
--leastPreventing | -lp   --> Run a search for single-elements preventing the least data, i.e. the least common elements.
--mostCommon      | -mc   --> Run a search for most common elements.
--bruteForce      | -bf   --> Provide ETA and run brute force algorithm. Note that it is not feasible for more than 20ish elements.
--geneticSearch   | -gs   --> Run a genetic search algorithm.
--algorithmSearch | -as   --> Run a custom problem-informed best-first search algorithm.
--develpment      | -d    --> DEPRECATED: Run development code.

"""

# ********* Core Routines *********

proc covBenchmark() =
    block:
        echo "Running coverage benchmark with int8 Tensor representation"

        let presenceTensor = getPresenceTensor()
        var b = zeros[int8](shape = [1, elementN])
        b[0, 0..5] = 1
        echo b

        benchmark "arraymancer+randomizing", verbose=true:
            discard preventedData(randomTensor[int8](shape = [1, elementN], sample_source = [0.int8, 1.int8]),
                                    presenceTensor)
        echo "Prevented count:", preventedData(b, presenceTensor)

    block:
        echo "\nRunning coverage benchmark with BitArray representation"
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
        echo "\nRunning coverage benchmark with bool arrays representation (BitArray graph retained)"
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
    block:
        echo "\nRunning coverage benchmark with BitArray representation:"
        let
            bb = BitArray()
            presenceBitArrays = getPresenceBitArrays()

        var esTemp = newElSolution(bb, presenceBitArrays)
        echo esTemp.getNextNodes(BitArray(), presenceBitArrays)
        benchmark "Expanding to elementN nodes 1000 times from empty", verbose=true:
            discard esTemp.getNextNodes(bb, presenceBitArrays)

        benchmark "Expanding to 1-elementN nodes 1000 times from random", verbose=true:
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
        echo "\nRunning coverage benchmark with bool arrays representation (BitArray graph retained)"
        let bb = BitArray()
        let presenceBoolArrays = getPresenceBoolArrays()
        var esTemp = newElSolution(bb, presenceBoolArrays)

        benchmark "Expanding to elementN nodes 1000 times from empty", verbose=true:
            discard esTemp.getNextNodes(bb, presenceBoolArrays)

        benchmark "Expanding to 1-elementN nodes 1000 times from random", verbose=true:
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
    let lpSol = leastPreventing(false).reversed()
    if verbose:
        for sol in lpSol: echo sol
    result = lpSol


proc algorithmSearch*(verbose: bool = true): seq[ElSolution] =
    let presenceBitArrays = getPresenceBitArrays()

    var solutions = initHeapQueue[ElSolution]()

    benchmarkOnce "exploring", verbose:
        solutions.push(newElSolution(BitArray(), presenceBitArrays))
        var toExpand: ElSolution
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

            if verbose: echo order, "=>", solutions[0], " => Tree Size:", len(solutions)
            result.add(solutions[0])


proc bruteForce*(verbose: bool = true): seq[ElSolution] =
    assert elementN <= 64, "Brute force is not feasible for more than around 30 elements, thus it is not implemented for above 64 elements."
    if verbose: styledEcho "\nRunning brute force algorithm for ", styleBright, fgMagenta, $elementN, resetStyle, " elements."
    let presenceBitArrays = getPresenceBitArrays()
    const solutionN = 2^elementN - 1
    if verbose: styledEcho "Solution space size: ", styleBright, fgMagenta, $solutionN, resetStyle

    timeEstimate solutionN:
        let elBA = BitArray(bits: [1])
        discard newElSolution(elBA, presenceBitArrays)
        discard elBA.count

    const solutionRange = 0.uint64..solutionN.uint64
    var topSolutions: array[elementN+1, ElSolution]
    benchmarkOnce "exploring", verbose:
        for c in solutionRange:
            let elBA = BitArray(bits: [c])
            let elSol = newElSolution(elBA, presenceBitArrays)
            let order = elBA.count
            if topSolutions[order].isNil:
                topSolutions[order] = elSol
            elif topSolutions[order] > elSol:
                topSolutions[order] = elSol
        for sol in topSolutions:
            if verbose: echo sol
            result.add(sol)

proc geneticSearch*(verbose: bool = true): seq[ElSolution] =
    let presenceBitArrays = getPresenceBitArrays()

    benchmarkOnce "exploring", verbose:
        var solutions = initHeapQueue[ElSolution]()
        for sol in getNextNodes(ElSolution(), BitArray(), presenceBitArrays):
            solutions.push(sol)
        if verbose: echo solutions[0]
        result.add(solutions[0])

        for order in 2..<elementN:
            solutions = initHeapQueue[ElSolution]()
            # Initialize with random 100 solutions
            for i in 1..1000:
                solutions.push(newElSolutionRandomN(order, presenceBitArrays))
            # Iterate UP TO 1,000 times (until converged)
            var bestValuesSeq = @[solutions[0].prevented]
            for i in 0..1000:
                var
                    top20set = initOrderedSet[ElSolution]()
                    newSolutions = initOrderedSet[ElSolution]()
                # Acquire top solutions
                let topSolution = solutions.pop()
                bestValuesSeq.add(topSolution.prevented)
                top20set.incl(topSolution)
                while len(top20set) < 100 and len(solutions) > 0:
                    top20set.incl(solutions.pop())
                let top20seq = top20set.toSeq
                # Generate new solutions through mutations
                for sol in top20seq:
                    var tempSol = ElSolution(elBA: sol.elBA)
                    tempSol.mutate(presenceBitArrays)
                    newSolutions.incl(sol)
                    newSolutions.incl(tempSol)
                # Generate new solutions through crossovers
                for i in countup(1, len(top20seq)-1, 2):
                    var tempSol1 = ElSolution(elBA: top20seq[i-1].elBA)
                    var tempSol2 = ElSolution(elBA: top20seq[i].elBA)
                    crossover(tempSol1, tempSol2, presenceBitArrays)
                    newSolutions.incl(tempSol1)
                    newSolutions.incl(tempSol2)
                # Push new solutions to queue
                for sol in newSolutions:
                    solutions.push(sol)
                # Check if converged
                if i > 10:
                    if bestValuesSeq[^10] == bestValuesSeq[^1]:
                        break

            if verbose: echo order, "=>", solutions[0], " => Queue Size:", len(solutions)
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
        discard algorithmSearch()

    if "--bruteForce" in args or "-bf" in args:
        discard bruteForce()

    if "--geneticSearch" in args or "-gs" in args:
        discard geneticSearch()

    if "--leastPreventing" in args or "-lp" in args:
        discard leastPreventing()

    if "--mostCommon" in args or "-mc" in args:
        discard mostCommon()

    echo "\nnimCSO Done!"





