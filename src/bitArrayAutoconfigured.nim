# The MIT License (MIT)
# Copyrigth (C) 2023 Adam M. Krajewski
# Copyright (c) 2020 Andre von Houck

import std/hashes
import std/bitops
import yaml
import std/strutils

# Load config YAML file
type Config = object
    taskName: string
    taskDescription: string
    elementOrder: seq[string]
    datasetPath: string

const config = static:
    var config: Config
    let s = readFile("config.yaml")
    load(s, config)
    config

const elementOrder = config.elementOrder
const elementN = elementOrder.len

func divUp(a, b: int): int =
  ## Like div, but rounds up instead of down.
  let extra = if a mod b > 0: 1 else: 0
  return a div b + extra

const lenInt64 = elementN.divUp(64)
echo "Using ", lenInt64, " uint64s to store ", elementN, " elements."

type BitArray* = object
  ## Creates an array of bits all packed in together.
  bits*: array[lenInt64, uint64]

when defined(release):
  {.push checks: off.}

func firstFalse*(b: BitArray): (bool, int) =
  for i in 0 ..< lenInt64:
    if b.bits[i] == 0:
      return (true, i * 64)
    if b.bits[i] != uint64.high:
      let matchingBits = firstSetBit(not b.bits[i])
      return (true, i * 64 + matchingBits - 1)
  (false, 0)

func unsafeGet*(b: BitArray, i: int): bool =
  ## Access a single bit (unchecked).
  let
    bigAt = i div 64
    littleAt = i mod 64
    mask = 1.uint64 shl littleAt
  return (b.bits[bigAt] and mask) != 0

func unsafeSetFalse*(b: var BitArray, i: int) =
  ## Set a single bit to false (unchecked).
  let
    bigAt = i div 64
    littleAt = i mod 64
    mask = 1.uint64 shl littleAt
  b.bits[bigAt] = b.bits[bigAt] and (not mask)

func unsafeSetTrue*(b: var BitArray, i: int) =
  ## Set a single bit to true (unchecked).
  let
    bigAt = i div 64
    littleAt = i mod 64
    mask = 1.uint64 shl littleAt
  b.bits[bigAt] = b.bits[bigAt] or mask

when defined(release):
  {.pop.}

func `[]`*(b: BitArray, i: int): bool =
  ## Access a single bit.
  if i < 0 or i >= elementN:
    raise newException(IndexDefect, "Index out of bounds")
  b.unsafeGet(i)

func `[]=`*(b: var BitArray, i: int, v: bool) =
  # Set a single bit.
  if i < 0 or i >= elementN:
    raise newException(IndexDefect, "Index out of bounds")
  if v:
    b.unsafeSetTrue(i)
  else:
    b.unsafeSetFalse(i)

func `==`*(a, b: var BitArray): bool =
  ## Are two bit arrays the same.
  for i in 0 ..< lenInt64:
    if a.bits[i] != b.bits[i]:
      return false
  return true

func `and`*(a, b: BitArray): BitArray =
  ## And(s) two bit arrays returning a new bit array.
  result = BitArray()
  for i in 0 ..< lenInt64:
    result.bits[i] = a.bits[i] and b.bits[i]

func `or`*(a, b: BitArray): BitArray =
  ## Or(s) two bit arrays returning a new bit array.
  result = BitArray()
  for i in 0 ..< lenInt64:
    result.bits[i] = a.bits[i] or b.bits[i]

func `not`*(a: BitArray): BitArray =
  ## Not(s) or inverts a and returns a new bit array.
  result = BitArray()
  for i in 0 ..< lenInt64:
    result.bits[i] = not a.bits[i]

func `$`*(b: BitArray): string =
  ## Turns the bit array into a string.
  result = newStringOfCap(elementN)
  for i in 0 ..< elementN:
    if b[i]:
      result.add "1"
    else:
      result.add "0"

func count*(b: BitArray): int =
  ## Returns the number of bits set.
  for i in 0 ..< lenInt64:
    result += countSetBits(b.bits[i])

func clear*(b: var BitArray) =
  ## Unsets all of the bits.
  for i in 0 ..< lenInt64:
    b.bits[i] = 0

func hash*(b: BitArray): Hash =
  ## Computes a Hash for the bit array.
  hash(b.bits)

iterator items*(b: BitArray): bool =
  for i in 0 ..< elementN:
    yield b[i]

iterator pairs*(b: BitArray): (int, bool) =
  for i in 0 ..< elementN:
    yield (i, b[i])

func toBoolArray*(b: BitArray): array[elementN, bool] =
  ## Converts the bit array to a sequence of bools.
  for i in 0 ..< elementN:
    result[i] = b.unsafeGet(i)