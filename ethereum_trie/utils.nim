import rlp/types as rlpTypes, strutils, nimcrypto/hash, parseutils

proc toMemRange*(r: BytesRange): MemRange =
  makeMemRange(r.baseAddr, r.len)

proc toHex*(r: BytesRange): string =
  result = newStringOfCap(r.len * 2)
  for c in r:
    result.add toHex(c.ord, 2)

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
