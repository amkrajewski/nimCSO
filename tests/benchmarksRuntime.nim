import std/unittest

import ../nimcso/nimcso {.all.}

suite "Runtime tests for benchmarks":
    test "Coverage Benchmark Run":
        covBenchmark()
    test "Expansions Benchmark Run":
        expBenchmark()