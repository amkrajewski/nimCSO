# Copyrigth (C) 2023 Adam M. Krajewski

import std/sugar
import arraymancer
import strutils
import times
import bitty
import os

when compileOption("profiler"):
  import nimprof

let elementOrder* = ["Fe", "Cr", "Ni", "Co", "Al", "Ti", "Nb", "Cu", "Mo", "Ta", "Zr",
                     "V",  "Hf", "W",  "Mn", "Si", "Re", "B'", "Ru", "C",  "Sn", "Mg",
                     "Zn", "Li", "O",  "Y",  "Pd", "N",  "Ca", "Ir", "Sc", "Ge", "Be", 
                     "Ag", "Nd", "S", "Ga"]

proc getPresenceTensor(): Tensor[uint8] =
    let elementsPresentList = readFile("elementLists.txt").splitLines()
    var
        presence = newTensor[uint8]([elementsPresentList.len, elementOrder.len])
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

proc getPresenceBitArrays(): seq[BitArray] =
    let elementsPresentList = readFile("elementLists.txt").splitLines()
    var
        presence = newBitArray(elementOrder.len)
        elN: int = 0

    for line in elementsPresentList:
        let elements = line.split(",")
        elN = 0
        for el in elementOrder:
            if elements.contains(el):
                presence[elN] = true
            elN += 1
        result.add(presence)
        presence = newBitArray(elementOrder.len)

proc preventedData(elList: BitArray, presenceBitArrays: seq[BitArray]): int =
    func isPrevented(elList: BitArray, presenceBitArray: BitArray): bool =
        for i in 0..elList.len-1:
            if elList[i] and presenceBitArray[i]:
                return true
        return false
    for pm in presenceBitArrays:
        if isPrevented(elList, pm):
            result += 1

proc preventedData(elList: Tensor[uint8], presenceTensor: Tensor[uint8]): int =
    let c = presenceTensor *. elList
    result = c.max(axis=1).asType(int).sum()


template benchmark(benchmarkName: string, code: untyped) =
  block:
    let t0 = epochTime()
    code
    let elapsed = (epochTime() - t0)*1000
    let elapsedStr = elapsed.formatFloat(format = ffDecimal, precision = 1)
    echo "CPU Time [", benchmarkName, "] ", elapsedStr, "ms"

when isMainModule:
    let args = commandLineParams()
    if args.len == 0:
        echo "To use form command line, provide parameters. Currently supported:"
        echo "--covBenchmark | -cb     --> to run small coverage benchmarks with two implementations"

    if "--covBenchmark" in args or "-cb" in args:
        echo "Running coverage benchmark with uint8 Tensor representation"
    
        let presenceTensor = getPresenceTensor()
        var b = zeros[uint8](shape = [1, 37])
        b[0, 0..5] = 1
        echo b

        benchmark "arraymancer":
            for i in 1..1000:
                discard preventedData(b, presenceTensor)
            echo preventedData(b, presenceTensor)

        echo "\nRunning coverage benchmark with BitArray representation"
        let presenceBitArrays = getPresenceBitArrays()

        var bb = newBitArray(37)
        for i in 0..5:
            bb[i] = true
        echo bb

        benchmark "bitty":
            for i in 1..1000:
                discard preventedData(bb, presenceBitArrays)
            echo preventedData(bb, presenceBitArrays)
    
    echo "Done"





