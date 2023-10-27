import std/unittest
import std/strutils

import ../nimcso/nimcso

suite "Corectness Tests":
    setup:
        let pBitA = getPresenceBitArrays()
        let pBoolA = getPresenceBoolArrays()

        var referenceResult: seq[ElSolution]

        for line in readFile("bruteForce_ref.csv").splitLines():
            let 
                parts = line.split(",")
                elList = parts[0].strip().split('-')
                prevented = parts[2].strip().parseInt()
            var elSol = newElSolution(elList, pBitA)
            elSol.prevented = prevented
            referenceResult.add(elSol)


    test "Brute Force Suite Complete":
        let result1 = leastPreventing()
        let result = bruteForce()

        for i in 1 ..< result.len:
            test $result[i]:
                check result[i].elBA == referenceResult[i-1].elBA
            test "^ Correctly prevents " & $referenceResult[i-1].prevented:
                check result[i].prevented == referenceResult[i-1].prevented

        saveResults(result, "bruteForce.csv", "-")