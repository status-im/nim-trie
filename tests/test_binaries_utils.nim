import
  unittest, strutils,
  ranges/bitranges, rlp/types, nimcrypto/[keccak, hash],
  eth_trie/[binaries, utils],
  test_utils

proc parseBitVector(x: string): BitRange =
  result = genBitVec(x.len)
  for i, c in x:
    result[i] = (c == '1')

const
  commonPrefixData = [
    (@[0b0000_0000.byte], @[0b0000_0000.byte], 8),
    (@[0b0000_0000.byte], @[0b1000_0000.byte], 0),
    (@[0b1000_0000.byte], @[0b1100_0000.byte], 1),
    (@[0b0000_0000.byte], @[0b0100_0000.byte], 1),
    (@[0b1110_0000.byte], @[0b1100_0000.byte], 2),
    (@[0b0000_1111.byte], @[0b1111_1111.byte], 0)
  ]

suite "binaries utils":

  test "get common prefix length":
    for c in commonPrefixData:
      var
        c0 = c[0]
        c1 = c[1]
      let actual_a = getCommonPrefixLength(c0.bits, c1.bits)
      let actual_b = getCommonPrefixLength(c1.bits, c0.bits)
      let expected = c[2]
      check actual_a == actual_b
      check actual_a == expected

  const
    None = ""
    parseNodeData = {
      "\x00\x03\x04\x05\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p":
        (0, "00110000010000000101", "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p"),
      "\x01\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p":
        (1, "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p"),
      "\x02value": (2, None, "value"),
      "": (0, None, None),
      "\x00\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p": (0, None, None),
      "\x01\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p": (0, None, None),
      "\x01\x02\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p":
        (0, None, None),
      "\x02": (0, None, None),
      "\x03": (0, None, None)
    }

  test "node parsing":
    var x = 0
    for c in parseNodeData:
      let input = toRange(c[0])
      let node = c[1]
      let kind = TrieNodeKind(node[0])
      try:
        let res = parseNode(input)
        check(kind == res.kind)
        case res.kind
        of KV_TYPE:
          check(res.keyPath == parseBitVector(node[1]))
          check(res.child == toRange(node[2]))
        of BRANCH_TYPE:
          check(res.leftChild == toRange(node[2]))
          check(res.rightChild == toRange(node[2]))
        of LEAF_TYPE:
          check(res.value == toRange(node[2]))
      except InvalidNode as E:
        discard
      except:
        echo getCurrentExceptionMsg()
        check(false)
      inc x

  const
    kvData = [
      ("0", "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", "\x00\x10\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p"),
      (""    , "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", None),
      ("0", "\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", None),
      ("1", "\x00\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", None),
      ("2", "", None)
    ]

  test "kv node encoding":
    for c in kvData:
      let keyPath = parseBitVector(c[0])
      let node    = toRange(c[1])
      let output  = toBytes(c[2])

      try:
        check output == encodeKVNode(keyPath, node)
      except ValidationError as E:
        discard
      except:
        check(getCurrentExceptionMsg() == "len(childHash) == 32 ")

  const
    branchData = [
      ("\xc8\x9e\xfd\xaaT\xc0\xf2\x0cz\xdfa(\x82\xdf\tP\xf5\xa9Qc~\x03\x07\xcd\xcbLg/)\x8b\x8b\xc6", "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p",
        "\x01\xc8\x9e\xfd\xaaT\xc0\xf2\x0cz\xdfa(\x82\xdf\tP\xf5\xa9Qc~\x03\x07\xcd\xcbLg/)\x8b\x8b\xc6\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p"),
      ("", "\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", None),
      ("\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", "\x01", None),
      ("\xc5\xd2F\x01\x86\xf7#<\x92~}\xb2\xdc\xc7\x03\xc0\xe5\x00\xb6S\xca\x82';{\xfa\xd8\x04]\x85\xa4p", "12345", None),
      (repeat('\x01', 33), repeat('\x01', 32), None),
    ]

  test "branch node encode":
    for c in branchData:
      let left   = toRange(c[0])
      let right  = toRange(c[1])
      let output = toBytes(c[2])

      try:
        check output == encodeBranchNode(left, right)
      except AssertionError as E:
        check (E.msg == "len(leftChildHash) == 32 ") or (E.msg == "len(rightChildHash) == 32 ")
      except:
        check(false)

  const
    leafData = [
      ("\x03\x04\x05", "\x02\x03\x04\x05"),
      ("", None)
    ]

  test "leaf node encode":
    for c in leafData:
      try:
        check toBytes(c[1]) == encodeLeafNode(toRange(c[0]))
      except ValidationError as E:
        discard
      except:
        check(false)

  test "random kv encoding":
    let lengths = randList(int, randGen(1, 999), randGen(100, 100), unique = false)
    for len in lengths:
      var k = len
      var bitvec = genBitVec(len)
      var nodeHash = keccak256.digest(cast[ptr byte](k.addr), uint(sizeof(int))).toRange
      var kvnode = encodeKVNode(bitvec, nodeHash).toRange
      # first byte if KV_TYPE
      # in the middle are 1..n bits of binary-encoded-keypath
      # last 32 bytes are hash
      var keyPath = decodeToBinKeypath(kvnode[1..^33])
      check kvnode[0].ord == KV_TYPE.ord
      check keyPath == bitvec
      check kvnode[^32..^1] == nodeHash
