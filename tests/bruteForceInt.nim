import std/unittest

import ../src/nimcso

suite "Corectness Tests":
    test "Verify Brute Force / Brute Foce Int Consistency":
        let resultStandard = bruteForce(verbose=false)
        let resultInt = bruteForceInt(verbose=false)

        test "Results have the same length":
            check resultStandard.len == resultInt.len

        for i in 1 ..< resultStandard.len:
            test $resultStandard[i] & " is the same in both results":
                check resultStandard[i] == resultInt[i]