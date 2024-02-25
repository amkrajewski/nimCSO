# The MIT License (MIT)
# Copyright (C) 2023 Adam M. Krajewski
# Copyright (c) 2020 Andre von Houck

import std/hashes
import std/bitops
import yaml
import std/strutils
import std/terminal

# Load config YAML file
type Config = object
    taskName: string
    taskDescription: string
    elementOrder: seq[string]
    datasetPath: string

const
    configPath {.strdefine.}: string = "config.yaml"
    config = static:
        var config: Config
        let s = readFile(configPath)
        load(s, config)
        config

    elementOrder = config.elementOrder
    elementN = elementOrder.len

func divUp(a, b: int): int =
    ## Like div, but rounds up instead of down.
    let extra = if a mod b > 0: 1 else: 0
    return a div b + extra

const lenInt64* = elementN.divUp(64) ## **Compile-time constant** of the number of ``uint64`` in the array used to store elements in the ``BitArray``.
styledEcho "Using ", styleBright, fgMagenta, $lenInt64, " uint64s", resetStyle, " to store ", styleBright, fgMagenta, $elementN, resetStyle, " elements."
# Side Note: There is a good reason to use uint64 even if the problem is smaller. The reason is performance. A 64-bit CPU is much better at handling 64-bit numbers; thus even if you hard-code the type 
# of the bit array values to be uint8 or uint16, the compiler will likely align them to fill 64-bit boundaries anyways, so there won't be any memory savings, while it will be slightly slower. E.g.,
# [1, uint64] -> CPU Time [Expanding to elementN nodes 1000 times from empty] 1011.2us   | -as with default config.yaml at step 24 -> 222.3 MB RAM
# [3, utin16] -> CPU Time [Expanding to elementN nodes 1000 times from empty] 1049.2us   | -as with default config.yaml at step 24 -> 223.7 MB RAM

type BitArray* = object
    ## Creates an array of bits all packed in together.
    bits*: array[lenInt64, uint64]

when defined(release):
    {.push checks: off.}

func firstFalse*(b: BitArray): (bool, int) =
    ## Returns the value and position of the first false bit in [BitArray].
    for i in 0 ..< lenInt64:
        if b.bits[i] == 0:
            return (true, i * 64)
        if b.bits[i] != uint64.high:
            let matchingBits = firstSetBit(not b.bits[i])
            return (true, i * 64 + matchingBits - 1)
    (false, 0)

func unsafeGet*(b: BitArray, i: int): bool =
    ## Access a single bit (unchecked) of the [BitArray] at position ``i``.
    let
        bigAt = i div 64
        littleAt = i mod 64
        mask = 1.uint64 shl littleAt
    return (b.bits[bigAt] and mask) != 0

func unsafeSetFalse*(b: var BitArray, i: int) =
    ## Set a single bit to ``false`` (unchecked) of the [BitArray] at position ``i``.
    let
        bigAt = i div 64
        littleAt = i mod 64
        mask = 1.uint64 shl littleAt
    b.bits[bigAt] = b.bits[bigAt] and (not mask)

func unsafeSetTrue*(b: var BitArray, i: int) =
    ## Set a single bit to ``true`` (unchecked) of the [BitArray] at position ``i``.
    let
        bigAt = i div 64
        littleAt = i mod 64
        mask = 1.uint64 shl littleAt
    b.bits[bigAt] = b.bits[bigAt] or mask

when defined(release):
    {.pop.}

func `[]`*(b: BitArray, i: int): bool =
    ## Access a single bit of the [BitArray] at position ``i``, with bounds checking.
    if i < 0 or i >= elementN:
        raise newException(IndexDefect, "Index out of bounds")
    b.unsafeGet(i)

func `[]=`*(b: var BitArray, i: int, v: bool) =
    # Set a single bit of the [BitArray] at position ``i``, with bounds checking.
    if i < 0 or i >= elementN:
        raise newException(IndexDefect, "Index out of bounds")
    if v:
        b.unsafeSetTrue(i)
    else:
        b.unsafeSetFalse(i)

func `==`*(a, b: var BitArray): bool =
    ## Checks equality of two [BitArray]s by comparing ``unit64`` values in their ``bits`` fields.
    for i in 0..<lenInt64:
        if a.bits[i] != b.bits[i]:
            return false
    return true

func `and`*(a, b: BitArray): BitArray =
    ## Applies ``AND`` over all positions of two [BitArray]s returning a new [BitArray].
    result = BitArray()
    for i in 0..<lenInt64:
        result.bits[i] = a.bits[i] and b.bits[i]

func `or`*(a, b: BitArray): BitArray =
    ## Applies ``OR`` over all positions of two [BitArray]s returning a new [BitArray].
    result = BitArray()
    for i in 0..<lenInt64:
        result.bits[i] = a.bits[i] or b.bits[i]

func `not`*(a: BitArray): BitArray =
    ## Applies ``NOT`` over all positions of a [BitArray] returning a new [BitArray].
    result = BitArray()
    for i in 0..<lenInt64:
        result.bits[i] = not a.bits[i]

func `$`*(b: BitArray): string =
    ## Returns a string representation of the [BitArray] as a string of ``0``s and ``1``s.
    result = newStringOfCap(elementN)
    for i in 0..<elementN:
        if b[i]:
            result.add "1"
        else:
            result.add "0"

proc styledEcho*(b: BitArray) =
    ## Prints the [BitArray] in a stylish way, with ``1``s in bright green and ``0``s in dim red.
    for i in 0..<elementN:
        if b[i]:
            stdout.styledWrite styleBright, fgGreen, "1"
        else:
            stdout.styledWrite styleDim, fgRed, "0"
    styledEcho resetStyle

proc styledEchoAnnotated*(b: BitArray) =
    ## Prints the [BitArray] in a stylish way, with (1) top annotation of the index like ``| 0| 1| 2| ... |10|11| ...``, (2) side annotation of the lenght of the array, 
    ## and (3) ``1``s in bright green and ``0``s in dim red.
    # Top annotation
    stdout.styledWrite styleDim, "    "
    for i in 1..elementN:
            stdout.styledWrite styleDim, fgBlack, "|", fgBlue, ($i).align(2)
    styledEcho styleDim, "|"
    # Side annotation
    stdout.styledWrite styleDim, ($elementN).align(3), " "
    for i in 0..<elementN:
        if b[i]:
            stdout.styledWrite styleDim, "|", styleBright, fgGreen, " 1"
        else:
            stdout.styledWrite styleDim, "|", fgRed, " 0"
    styledEcho styleDim, "|"

func count*(b: BitArray): int =
    ## Returns the number of set bits in the [BitArray].
    for i in 0 ..< lenInt64:
        result += countSetBits(b.bits[i])

func clear*(b: var BitArray) =
    ## Unsets all of the bits in the [BitArray].
    for i in 0 ..< lenInt64:
        b.bits[i] = 0

func hash*(b: BitArray): Hash =
    ## Computes a Hash for the [BitArray] by hasing the array of ``uint64``s.
    hash(b.bits)

iterator items*(b: BitArray): bool =
    ## Iterates over the bits of the [BitArray] yielding ``true`` or ``false``.
    for i in 0 ..< elementN:
        yield b[i]

iterator pairs*(b: BitArray): (int, bool) =
    ## Iterates over the bits of the [BitArray] yielding the position and the ``true`` or ``false`` value.
    for i in 0 ..< elementN:
        yield (i, b[i])

func toBoolArray*(b: BitArray): array[elementN, bool] =
    ## Converts the [BitArray] to an array of ``bool``s.
    for i in 0 ..< elementN:
        result[i] = b.unsafeGet(i)

func toSetPositions*(b: BitArray): seq[int] =
    ## Converts the [BitArray] to a sequence of positions of the ``true`` bits.
    for i in 0 ..< elementN:
        if b.unsafeGet(i):
            result.add i
