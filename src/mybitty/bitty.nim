import hashes, bitops

type BitArray* = object
  ## Creates an array of bits all packed in together.
  bits*: seq[uint64]
  len*: int

func divUp(a, b: int): int =
  ## Like div, but rounds up instead of down.
  let extra = if a mod b > 0: 1 else: 0
  return a div b + extra

func newBitArray*(len: int = 0): BitArray =
  ## Create a new bit array.
  result = BitArray()
  result.len = len
  result.bits = newSeq[uint64](len.divUp(64))

func setLen*(b: var BitArray, len: int) =
  ## Sets the length.
  b.len = len
  b.bits.setLen(len.divUp(64))

when defined(release):
  {.push checks: off.}

func firstFalse*(b: BitArray): (bool, int) =
  for i in 0 ..< b.bits.len:
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
  if i < 0 or i >= b.len:
    raise newException(IndexDefect, "Index out of bounds")
  b.unsafeGet(i)

func `[]=`*(b: var BitArray, i: int, v: bool) =
  # Set a single bit.
  if i < 0 or i >= b.len:
    raise newException(IndexDefect, "Index out of bounds")
  if v:
    b.unsafeSetTrue(i)
  else:
    b.unsafeSetFalse(i)

func `==`*(a, b: var BitArray): bool =
  ## Are two bit arrays the same.
  if a.len != b.len:
    return false
  for i in 0 ..< a.bits.len:
    if a.bits[i] != b.bits[i]:
      return false
  return true

func `and`*(a, b: BitArray): BitArray =
  ## And(s) two bit arrays returning a new bit array.
  if a.len != b.len:
    raise newException(ValueError, "Bit arrays are not same length")
  result = newBitArray(a.len)
  for i in 0 ..< a.bits.len:
    result.bits[i] = a.bits[i] and b.bits[i]

func `or`*(a, b: BitArray): BitArray =
  ## Or(s) two bit arrays returning a new bit array.
  if a.len != b.len:
    raise newException(ValueError, "Bit arrays are not same length")
  result = newBitArray(a.len)
  for i in 0 ..< a.bits.len:
    result.bits[i] = a.bits[i] or b.bits[i]

func `not`*(a: BitArray): BitArray =
  ## Not(s) or inverts a and returns a new bit array.
  result = newBitArray(a.len)
  for i in 0 ..< a.bits.len:
    result.bits[i] = not a.bits[i]

func `$`*(b: BitArray): string =
  ## Turns the bit array into a string.
  result = newStringOfCap(b.len)
  for i in 0 ..< b.len:
    if b[i]:
      result.add "1"
    else:
      result.add "0"

func add*(b: var BitArray, v: bool) =
  ## Add a bit to the end of the array.
  let
    i = b.len
  b.len += 1
  if b.len.divUp(64) > b.bits.len:
    b.bits.add(0)
  if v:
    let
      bigAt = i div 64
      littleAt = i mod 64
      mask = 1.uint64 shl littleAt
    b.bits[bigAt] = b.bits[bigAt] or mask

func count*(b: BitArray): int =
  ## Returns the number of bits set.
  for i in 0 ..< b.bits.len:
    result += countSetBits(b.bits[i])

func clear*(b: var BitArray) =
  ## Unsets all of the bits.
  for i in 0 ..< b.bits.len:
    b.bits[i] = 0

func hash*(b: BitArray): Hash =
  ## Computes a Hash for the bit array.
  hash((b.bits, b.len))

iterator items*(b: BitArray): bool =
  for i in 0 ..< b.len:
    yield b[i]

iterator pairs*(b: BitArray): (int, bool) =
  for i in 0 ..< b.len:
    yield (i, b[i])

func toBoolSeq*(b: BitArray): seq[bool] =
  ## Converts the bit array to a sequence of bools.
  result = newSeq[bool](b.len)
  for i in 0 ..< b.len:
    result[i] = b.unsafeGet(i)

type BitArray2d* = ref object
  ## Creates an array of bits all packed in together.
  bits: BitArray
  stride: int

func newBitArray2d*(stride, len: int): BitArray2d =
  ## Create a new bit array.
  result = BitArray2d()
  result.bits = newBitArray(stride * len)
  result.stride = stride

func `[]`*(b: BitArray2d, x, y: int): bool =
  b.bits[x * b.stride + y]

func `[]=`*(b: BitArray2d, x, y: int, v: bool) =
  b.bits[x * b.stride + y] = v

func `and`*(a, b: BitArray2d): BitArray2d =
  ## And(s) two bit arrays returning a new bit array.
  result = BitArray2d()
  result.bits = a.bits and b.bits
  result.stride = a.stride

func `or`*(a, b: BitArray2d): BitArray2d =
  ## Or(s) two bit arrays returning a new bit array.
  result = BitArray2d()
  result.bits = a.bits or b.bits
  result.stride = a.stride

func `not`*(a: BitArray2d): BitArray2d =
  ## Not(s) or inverts a and returns a new bit array.
  result = BitArray2d()
  result.bits = not a.bits
  result.stride = a.stride

func `==`*(a, b: BitArray2d): bool =
  ## Are two bit arrays the same.
  a.stride == b.stride and b.bits == a.bits

func hash*(b: BitArray2d): Hash =
  ## Computes a Hash for the bit array.
  hash((b.bits, b.bits.len, b.stride))

func `$`*(b: BitArray2d): string =
  ## Turns the bit array into a string.
  result = newStringOfCap(b.bits.len)
  result.add ("[\n")
  for i in 0 ..< b.bits.len:
    if i != 0 and i mod b.stride == 0:
      result.add "\n"
    if i mod b.stride == 0:
      result.add "  "
    if b.bits[i]:
      result.add "1"
    else:
      result.add "0"
  result.add ("\n]\n")
