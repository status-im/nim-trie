import
  strutils, parseutils,
  rlp/types as rlpTypes, ranges/ptr_arith,
  eth_common/eth_types, nimcrypto/[hash, keccak],
  binaries

#proc baseAddr*(x: Bytes): ptr byte = x[0].unsafeAddr

proc toTrieNodeKey*(hash: KeccakHash): TrieNodeKey =
  result = newRange[byte](32)
  copyMem(result.baseAddr, hash.data.baseAddr, 32)

template checkValidHashZ*(x: untyped) =
  when x.type isnot KeccakHash:
    assert(x.len == 32 or x.len == 0)

template isZeroHash*(x: BytesRange): bool =
  x.len == 0

template toRange*(hash: KeccakHash): BytesRange =
  toTrieNodeKey(hash)

proc toRange*(str: string): BytesRange =
  var s = newSeq[byte](str.len)
  if str.len > 0:
    copyMem(s[0].addr, str[0].unsafeAddr, str.len)
  result = toRange(s)

proc hashFromHex*(bits: static[int], input: string): MDigest[bits] =
  if input.len != bits div 4:
    raise newException(ValueError,
                       "The input string has incorrect size")

  for i in 0 ..< bits div 8:
    var nextByte: int
    if parseHex(input, nextByte, i*2, 2) == 2:
      result.data[i] = uint8(nextByte)
    else:
      raise newException(ValueError,
"The input string contains invalid characters")

template hashFromHex*(s: static[string]): untyped = hashFromHex(s.len * 4, s)

proc keccakHash*(input: openArray[byte]): BytesRange =
  var s = newSeq[byte](32)
  var ctx: keccak256
  ctx.init()
  if input.len > 0:
    ctx.update(input[0].unsafeAddr, uint(input.len))
  ctx.finish s
  ctx.clear()
  result = toRange(s)

proc keccakHash*(dest: var openArray[byte], a, b: openArray[byte]) =
  var ctx: keccak256
  ctx.init()
  if a.len != 0:
    ctx.update(a[0].unsafeAddr, uint(a.len))
  if b.len != 0:
    ctx.update(b[0].unsafeAddr, uint(b.len))
  ctx.finish dest
  ctx.clear()

proc keccakHash*(a, b: openArray[byte]): BytesRange =
  var s = newSeq[byte](32)
  keccakHash(s, a, b)
  result = toRange(s)

template keccakHash*(input: BytesRange): BytesRange =
  keccakHash(input.toOpenArray)

template keccakHash*(a, b: BytesRange): BytesRange =
  keccakHash(a.toOpenArray, b.toOpenArray)

template keccakHash*(dest: var BytesRange, a, b: BytesRange) =
  keccakHash(dest.toOpenArray, a.toOpenArray, b.toOpenArray)
