# The MIT License (MIT)
# Copyright (C) 2023 Adam M. Krajewski

## # Test
## ## Test2

runnableExamples:
    let presenceTensor = getPresenceTensor()

# Standard library imports
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

# Third-party library imports
import arraymancer
import yaml

# NimCSO imports
import bitArrayAutoconfigured

when compileOption("profiler"):
    import nimprof

# Load config YAML file
type Config = object
    taskName: string
    taskDescription: string
    elementOrder: seq[string]
    datasetPath: string

const
    configPath {.strdefine.}: string = "config.yaml"
    config = static:
        echo configPath
        var config: Config
        let s = readFile(configPath)
        load(s, config)
        config

    elementOrder* = config.elementOrder ## Compile-time-established configuration for the task
    elementN* = elementOrder.len ## Compile-time-established configuration for the task
    elementsPresentList = static:
        let elementSet = toHashSet(elementOrder)
        var result = newSeq[string]()
        for line in readFile(config.datasetPath).splitLines():
            let elements = toHashSet(line.split(",").map(el => el.strip()))
            if elements <= elementSet:
                result.add(line)
        result
    ## Compile-time-established configuration for the task
    alloyN* = elementsPresentList.len ## Compile-time-established configuration for the task

# Dataset Ingestion

proc getPresenceTensor*(): Tensor[int8] =
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
    result = presence

func getPresenceBitArrays*(): seq[BitArray] =
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

# Dataset-Solution Interactions

func preventedData*(elList: BitArray, presenceBitArrays: seq[BitArray]): int =
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
    let c = presenceTensor *. elList
    result = c.max(axis = 1).asType(int).sum()

# Solution class implementation

type ElSolution* = ref object
    elBA*: BitArray
    prevented*: int

proc newElSolution*(elBA: BitArray,
                    pBA: seq[BitArray] | seq[seq[bool]]): ElSolution =
    result = ElSolution()
    result.elBA = elBA
    result.prevented = preventedData(elBA, pBA)

proc newElSolution(elementSet: seq[string],
                   pBA: seq[BitArray] | seq[seq[bool]]): ElSolution =
    assert toHashSet(elementSet) <= toHashSet(elementOrder), "Element set is not a subset of the element order defined in the config."
    var elBA = BitArray()
    for i in 0..<elementN:
        if elementOrder[i] in elementSet:
            elBA[i] = true
    result = newElSolution(elBA, pBA)

proc newElSolutionRandomN*(order: int,
                           pBA: seq[BitArray] | seq[seq[bool]]): ElSolution =
    result = ElSolution(elBA: BitArray())
    while result.elBA.count < order:
        result.elBA[rand(elementN-1)] = true
    result.prevented = preventedData(result.elBA, pBA)

func hash*(elSol: ElSolution): Hash =
    hash(elSol.elBA)

proc `$`*(elSol: ElSolution): string =
    for i in 0..<elementN:
        if elSol.elBA[i]:
            result.add(elementOrder[i])
    result.add("->")
    result.add(elSol.prevented.intToStr())

func `<`*(a, b: ElSolution): bool = a.prevented < b.prevented

func `>`*(a, b: ElSolution): bool = a.prevented > b.prevented

proc `==`*(a, b: ElSolution): bool = a.elBA == b.elBA

func setPrevented*(elSol: var ElSolution,
                   presenceArrays: seq[BitArray] | seq[seq[bool]]): void =
    elSol.prevented = preventedData(elSol.elBA, presenceArrays)

proc randomize*(elSol: var ElSolution): void =
    for i in 0..<elementN:
        elSol.elBA[i] = (rand(1) > 0)

proc mutate*(elSol: var ElSolution, presenceArrays: seq[BitArray] | seq[seq[bool]]): void =
    let
        i = rand(elementN-1)
        j = rand(elementN-1)
    let temp = elSol.elBA[i]
    elSol.elBA[i] = elSol.elBA[j]
    elSol.elBA[j] = temp
    elSol.setPrevented(presenceArrays)

proc crossover*(elSol1: var ElSolution, elSol2: var ElSolution,
                presenceArrays: seq[BitArray] | seq[seq[bool]]): void =
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


# Exploration-Related Procedures

func getNextNodes*(elSol: ElSolution,
                   exclusions: BitArray,
                   presenceBitArrays: seq[BitArray] | seq[seq[bool]]): seq[ElSolution] =
    for i in 0..<elementN:
        if not elSol.elBA[i] and not exclusions[i]:
            var newElBA: BitArray
            newElBA = elSol.elBA
            newElBA[i] = true
            result.add(newElSolution(newElBA, presenceBitArrays))

# Result persistence into CSV

proc saveResults*(results: seq[ElSolution], path: string, separator: string = "-"): void =
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


# Helper Procedures

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

template loopEstimate(iterN: int, code: untyped) =
    block:
        let t0 = epochTime()
        for i in 1..1000:
            code
        let t1 = epochTime() - t0
        echo "Loop ETA Estimate: " & $initDuration(milliseconds = (t1 * iterN.float).int) & "\n"


proc echoHelp() = echo """
To use form command line, provide parameters. Currently supported usage:

--covBenchmark    | -cb   --> Run small coverage benchmarks under two implementations.
--expBenchmark    | -eb   --> Run small node expansion benchmarks.
--bruteForce      | -bf   --> Provide ETA and run brute force algorithm. Note that it is not feasible for more than 20ish elements.
--geneticSearch   | -gs   --> Run a genetic search algorithm.
--algorithmSearch | -as   --> Run a custom problem-informed best-first search algorithm.
--develpment      | -d    --> DEPRECATED: Run development code.

"""

# Core Routines

proc covBenchmark =
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
        echo bb
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
        echo bb
        let particularResult = newElSolution(bb, presenceBoolArrays)
        echo particularResult
        echo "Prevented count:", particularResult.prevented

proc expBenchmark =
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
        echo "Last solution on heap: ", solutions[0]

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
    if verbose: echo "\nRunning brute force algorithm for " & $elementN & " elements."
    let presenceBitArrays = getPresenceBitArrays()
    const solutionN = 2^elementN - 1
    if verbose: echo "Solution space size: ", solutionN

    loopEstimate solutionN:
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

# Main Routine

when isMainModule:
    let args = commandLineParams()
    if args.len == 0:
        echoHelp()

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

    echo "\nnimCSO Done!"





