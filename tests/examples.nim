import
  eth_trie/[memdb, binary, utils, branches, constants, types],
  nimcrypto/[keccak, hash], unittest

suite "examples":

  var memDB = newMemDB()
  var db = trieDB memDB
  var trie = initBinaryTrie(db)

  test "basic set/get":
    trie.set("key1", "value1")
    trie.set("key2", "value2")
    check trie.get("key1") == "value1".toRange
    check trie.get("key2") == "value2".toRange

  test "check branch exists":
    check checkIfBranchExist(db, trie.getRootHash(), "key") == true
    check checkIfBranchExist(db, trie.getRootHash(), "key1") == true
    check checkIfBranchExist(db, trie.getRootHash(), "ken") == false
    check checkIfBranchExist(db, trie.getRootHash(), "key123") == false

  test "branches utils":
    var branchA = getBranch(db, trie.getRootHash(), "key1")
    # ==> [A, B, C1, D1]
    check branchA.len == 4

    var branchB = getBranch(db, trie.getRootHash(), "key2")
    # ==> [A, B, C2, D2]
    check branchB.len == 4

    check isValidBranch(branchA, trie.getRootHash(), "key1", "value1") == true
    check isValidBranch(branchA, trie.getRootHash(), "key5", "") == true

    try:
      check isValidBranch(branchB, trie.getRootHash(), "key1", "value1") # Key Error
    except KeyError:
      check(true)
    except:
      check(false)

    var x = getBranch(db, trie.getRootHash(), "key")
    # ==> [A]
    check x.len == 1

    try:
      x = getBranch(db, trie.getRootHash(), "key123") # InvalidKeyError
    except InvalidKeyError:
      check(true)
    except:
      check(false)

    x = getBranch(db, trie.getRootHash(), "key5") # there is still branch for non-exist key
    # ==> [A]
    check x.len == 1

  test "getWitness":
    var branch = getWitness(db, trie.getRootHash(), "key1")
    # equivalent to `getBranch(db, trie.getRootHash(), "key1")`
    # ==> [A, B, C1, D1]
    check branch.len == 4

    branch = getWitness(db, trie.getRootHash(), "key")
    # this will include additional nodes of "key2"
    # ==> [A, B, C1, D1, C2, D2]
    check branch.len == 6

    branch = getWitness(db, trie.getRootHash(), "")
    # this will return the whole trie
    # ==> [A, B, C1, D1, C2, D2]
    check branch.len == 6

  let beforeDeleteLen = memDB.len
  test "verify intermediate entries existence":
    var branchs = getWitness(db, trie.getRootHash, zeroBytesRange)
    # set operation create new intermediate entries
    check branchs.len < beforeDeleteLen

    var node = branchs[1]
    let nodeHash = keccak256.digest(node.baseAddr, uint(node.len))
    var nodes = getTrieNodes(db, nodeHash)
    check nodes.len == branchs.len - 1

  test "delete sub trie":
    # delete all subtrie with key prefixes "key"
    trie.deleteSubtrie("key")
    check trie.get("key1") == zeroBytesRange
    check trie.get("key2") == zeroBytesRange

  test "prove the lie":
    # `delete` and `deleteSubtrie` not actually delete the nodes
    check memDB.len == beforeDeleteLen
    var branchs = getWitness(db, trie.getRootHash, zeroBytesRange)
    check branchs.len == 0

  test "dictionary syntax API":
    # dictionary syntax API
    trie["moon"] = "sun"
    check "moon" in trie
    check trie["moon"] == "sun".toRange
