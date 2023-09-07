# Copyrigth (C) 2023 Adam M. Krajewski

import math
import std/sugar
import arraymancer
import strutils
import times, os

proc preventedData(elList: Tensor[uint8]): int =
    let a = [[1,0,0,0,1], [1,0,0,1,0], [1,1,1,1,1], [0,0,0,0,0],
        [1,0,0,0,1], [1,0,0,1,0], [1,1,1,1,1], [0,0,0,0,0],
        [1,0,0,0,1], [1,0,0,1,0], [1,1,1,1,1], [0,0,0,0,0],
        [1,0,0,0,1], [1,0,0,1,0], [1,1,1,1,1], [0,0,0,0,0],
        [1,0,0,0,1], [1,0,0,1,0], [1,1,1,1,1], [0,0,0,0,0] ].toTensor().asType(uint8)
    var c = a *. elList
    c = c.max(axis=1)
    result = c.asType(int).sum()

template benchmark(benchmarkName: string, code: untyped) =
  block:
    let t0 = epochTime()
    code
    let elapsed = epochTime() - t0
    let elapsedStr = elapsed.formatFloat(format = ffDecimal, precision = 3)
    echo "CPU Time [", benchmarkName, "] ", elapsedStr, "s"

when isMainModule:
    let b = [[0, 1, 1, 1, 0]].toTensor().astype(uint8)
    benchmark "my benchmark":
        for i in 0..1000000:
            discard preventedData(b)



