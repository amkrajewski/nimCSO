import std/unittest
import std/strutils

import ../src/nimcso

suite "Lest Preventing / Most Common Corectness Tests":
    setup:
        let pBitA = getPresenceBitArrays()

        var referenceResult: seq[ElSolution]

        for line in readFile("tests/leastPreventing_ref.csv").splitLines():
            let 
                parts = line.split(",")
                el = @[parts[0].strip()]
                prevented = parts[2].strip().parseInt()
            var elSol = newElSolution(el, pBitA)
            elSol.prevented = prevented
            referenceResult.add(elSol)

    test "Persistance of Filtered Dataset":
        saveFilteredDataset("tests/filteredDataset_testResult.txt")

    test "Least Prevented Complete":
        let result = leastPreventing(verbose=false)

        for i in 1 ..< result.len:
            test $result[i]:
                check result[i].elBA == referenceResult[i].elBA
            test "^ Correctly prevents " & $referenceResult[i].prevented:
                check result[i].prevented == referenceResult[i].prevented

        saveResults(result, "tests/leastPreventing_testResult.csv", "-")