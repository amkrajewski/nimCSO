# Copyrigth (C) 2023 Adam M. Krajewski

import std/sugar
import arraymancer
import strutils
import times, os

proc preventedData(elList: Tensor[uint8], presenceMatrix: Tensor[uint8]): int =
    var c = presenceMatrix *. elList
    c = c.max(axis=1)
    result = c.asType(int).sum()

proc getPresenceMatrix(): Tensor[uint8] =
    let elementOrder = ["Fe", "Cr","Cr","Ni","Co","Al","Ti","Nb","Cu","Mo","Ta","Zr",
                        "V'","Hf","W'","Mn","Si","Re","B'","Ru","C'","Sn","Mg","Zn",
                        "Li","O'", "Y'", "Pd","N'", "Ca","Ir","Sc","Ge","Be","Ag",
                        "Nd","S'", "Ga"]

    let elementsPresentList = readFile("elementList.txt").splitLines()
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

template benchmark(benchmarkName: string, code: untyped) =
  block:
    let t0 = epochTime()
    code
    let elapsed = epochTime() - t0
    let elapsedStr = elapsed.formatFloat(format = ffDecimal, precision = 3)
    echo "CPU Time [", benchmarkName, "] ", elapsedStr, "s"

when isMainModule:
    
    let presenceMatrix = getPresenceMatrix()

    let b = [[0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0]].toTensor().astype(uint8)

    benchmark "my benchmark":
        for i in 0..1000:
            discard preventedData(b, presenceMatrix)
    #echo preventedData(b, presenceMatrix)



