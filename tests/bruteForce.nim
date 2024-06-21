import std/unittest
import std/strutils

import ../src/nimcso

suite "Correctness Tests":
    # Common setup for all tests without need to repeat it every time
    let pBitA = getPresenceBitArrays()

    var referenceResult: seq[ElSolution]

    for line in readFile("tests/bruteForce_ref.csv").splitLines():
        let 
            parts = line.split(",")
            elList = parts[0].strip().split('-')
            prevented = parts[2].strip().parseInt()
        var elSol = newElSolution(elList, pBitA)
        elSol.prevented = prevented
        referenceResult.add(elSol)
    
    test "Verify Bit/Bool Array Backend Consistency":
        # Please note the bakcedn is not the same (it is not a repetition of the same test)
        let pBoolA = getPresenceBoolArrays()
        var referenceResult_BoolA: seq[ElSolution]

        for line in readFile("tests/bruteForce_ref.csv").splitLines():
            let 
                parts = line.split(",")
                elList = parts[0].strip().split('-')
                prevented = parts[2].strip().parseInt()
            var elSol = newElSolution(elList, pBoolA)
            elSol.prevented = prevented
            referenceResult_BoolA.add(elSol)
        
        for i in 0 ..< referenceResult.len:
            check referenceResult[i] == referenceResult_BoolA[i]

    test "Brute Force Suite Complete":
        let result = bruteForce(verbose=false)

        for i in 1 ..< result.len:
            test $result[i]:
                check result[i].elBA == referenceResult[i-1].elBA
            test "^ Correctly prevents " & $referenceResult[i-1].prevented:
                check result[i].prevented == referenceResult[i-1].prevented

        saveResults(result, "tests/bruteForce_testResult.csv", "-")
