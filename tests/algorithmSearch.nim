import std/unittest
import std/strutils

import ../src/nimcso

suite "Corectness Tests":

    test "Algorithm Search results match the reference values":
        let pBitA = getPresenceBitArrays()

        var referenceResult: seq[ElSolution]

        for line in readFile("tests/algorithmSearch_ref.csv").splitLines():
            let 
                parts = line.split(",")
                elList = parts[0].strip().split('-')
                prevented = parts[2].strip().parseInt()
            var elSol = newElSolution(elList, pBitA)
            elSol.prevented = prevented
            referenceResult.add(elSol)

        let result = algorithmSearch(verbose=false)

        for i in 0 ..< result.len:
            test $result[i]:
                check result[i].elBA == referenceResult[i].elBA
            test "^ Correctly prevents " & $referenceResult[i].prevented:
                check result[i].prevented == referenceResult[i].prevented

        saveResults(result, "tests/algorithmSearch_testResult.csv", "-")

    if nimcso.configPath=="tests/config.yaml":
        test "^ Algorithm Search produces the same result as Brute Force for the test configuration (except for the last 3)":
            let bruteForceResult = bruteForce(verbose=false)
            let result = algorithmSearch(verbose=false)

            for i in 0..<result.len-3:
                test $result[i]:
                    check result[i] == bruteForceResult[i+1]

        