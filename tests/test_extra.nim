import std/assertions
import std/sequtils
import std/json
import std/options
import std/strutils

import ../protojson
import ../db_connector/db_sqlite
import ../extsqlite
import ../enum_ex
import ../model_stable/area_object
import ../model_stable/battle_enum
import ../model_stable/city
import utils

proc test_null() =
  let db = initMemoryDb()
  db.exec(sql"CREATE TABLE asd (x INTEGER, y INTEGER)")
  db.exec(sql"INSERT INTO asd (x, y) VALUES (null, 10)")

  let row = db.getRow(sql"SELECT x, y FROM asd")
  doAssert(row[0] == "")
  doAssert(row[1] == "10")


proc test_bool_is_not_zero_or_one() =
  let db = initMemoryDb()
  db.exec(sql"CREATE TABLE asd (x BOOLEAN)")
  db.exec(sql"INSERT INTO asd (x) VALUES (?)", true)

  let row = db.getRow(sql"SELECT x FROM asd")
  doAssert(row[0] == "true")


proc testSqlIntTuple() =
  let db = initMemoryDb()
  db.exec(sql"CREATE TABLE asd (id INTEGER, val INTEGER)")
  db.exec(sql"INSERT INTO asd (id, val) VALUES (1, 4), (2, 8), (3, 9)")

  let rows = db.getAllRows(sql("SELECT val FROM asd WHERE id IN " & sqlIntTuple([2, 3])))
  doAssert(rows.mapIt(it[0]) == ["8", "9"])


proc testEnumToJson() =
  type Bar = enum
    Bar1
    Bar2

  type Foo = object
    bar: Bar

  let foo = %*Foo(bar: Bar2)

  doAssert(foo["bar"].getStr() == "Bar2")

  # protoJsonTo(%*{"bar": ""}, Foo).bar == Bar1 # ValueError: Invalid enum value


proc testIntToEnum() =
  type Asd = enum
    asd1 = 10
    asd2 = 14
    asd3 = 20

  doAssert(intToEnum(10, Asd) == asd1)
  doAssert(intToEnum(14, Asd) == asd2)
  doAssert(intToEnum(20, Asd) == asd3)


proc testOptionToJson() =
  let x = some(10)
  let y = none(int)

  let xJson = %*x
  let yJson = %*y

  let xAgain = protoJsonTo(xJson, Option[int])
  let yAgain = protoJsonTo(yJson, Option[int])

  doAssert(x == xAgain)
  doAssert(y == yAgain)


proc testNilJsonField() =
  type Foo = object
    bar: JsonNode

  let x = toProtoJson(Foo())

  doAssert($x == "{\"bar\":null}") # SIGSEGV: Illegal storage access. (Attempt to read from nil?)


proc testGenStringEnumHooks() =
  type MockBattleFinishRequest = object
    battleResult: BattleResult

  doAssert(toProtoJson(MockBattleFinishRequest(battleResult: BattleResult.won)) == %*{"battleResult": "won"})

  let jsonReq = %*{}
  let req = protoJsonTo(jsonReq, MockBattleFinishRequest)
  doAssert(req.battleResult == BattleResult.won)


proc testSqliteMin() =
  let db = initMemoryDb()

  db.exec(sql"CREATE TABLE asd (x INTEGER)")
  db.exec(sql"INSERT INTO asd VALUES (10)")

  let addAmount = 30
  let maxAmount = 20

  db.exec(sql"UPDATE asd SET x = min(CAST(? as INTEGER), x + ?)", maxAmount, addAmount)

  let amount = parseInt(db.getRow(sql"SELECT x FROM asd")[0])
  doAssert(amount == 20)


proc testJsonNodeFields() =
  let nodes = @[%*{"areaChangeLockId": 1234}] # seq[JsonNode]

  let jsonData = toProtoJson(nodes)

  doAssert(jsonData[0].keys().toSeq() == @["areaChangeLockId"])


proc testChallengeIdToCityId() =
  let cityIds = [100, 1021, 10301, 100131].mapIt(challengeIdToCityId(it))
  doAssert(cityIds.allIt(it == cityIdShinagawa))


proc testNullOrdinalField() =
  let x = %*{"asd": nil}
  doAssert(x["asd"].kind == JNull)
  type X = object
    asd: int

  doAssert(x.protoJsonTo(X).asd == 0)


proc testGetTheHighestPriority() =
  let aobs = [
    MdAreaObjectBehavior(id: 1, priority: 100),
    MdAreaObjectBehavior(id: 2, priority: 200),
    MdAreaObjectBehavior(id: 3, priority: 50),
  ]
  
  doAssert(getTheHighestPriority(aobs).id == 2)


proc testSuiteExtra*() =
  test_null()
  test_bool_is_not_zero_or_one()
  testSqlIntTuple()
  testEnumToJson()
  testIntToEnum()
  testOptionToJson()
  testNilJsonField()
  testGenStringEnumHooks()
  testSqliteMin()
  testJsonNodeFields()
  testChallengeIdToCityId()
  testNullOrdinalField()
  testGetTheHighestPriority()