import std/assertions
import std/options
import std/json

import ../db_connector/db_sqlite
import ../semba
import ../sembaprivate
import ../model_stable/battle
import ../model_stable/reward


proc initMemoryDb(): DbConn = open(":memory:", "", "", "")


proc sembaCall*(ctx: var SembaExContext, path: string, body: JsonNode): JsonNode =
  let bodyStr = if body != nil: $body else: ""
  let resultStr = sembaExCallImpl(ctx, path, bodyStr)

  if resultStr != "":
    result = parseJson(resultStr)


proc itemsTableExists(db: DbConn): bool =
  result = db.getRow(sql"SELECT name FROM sqlite_schema WHERE name = 'items'")[0] == "items"


proc getInMemorySembaCtx*(): SembaExContext =
  result = SembaExContext(gameVersion: gameVersion_1_1_3_35, db: initMemoryDb(), lastBattleInfo: none(BattleInfo))
  discard sembaCall(result, "/semba/reset_db", nil)


proc loadSaveFile*(ctx: var SembaExContext, saves_dir: string, name: string) =
  discard sembaCall(ctx, "/semba/load_save_file", %*{
    "saves_dir": saves_dir,
    "name": name,
  })


proc test_reset_db(): int =
  var ctx = SembaExContext(gameVersion: gameVersion_1_1_3_35, db: initMemoryDb(), lastBattleInfo: none(BattleInfo))

  doAssert(not itemsTableExists(ctx.db))

  discard sembaCall(ctx, "/semba/reset_db", nil)

  doAssert(itemsTableExists(ctx.db))


proc test_null() =
  let db = initMemoryDb()
  db.exec(sql"CREATE TABLE asd (x INTEGER, y INTEGER)")
  db.exec(sql"INSERT INTO asd (x, y) VALUES (null, 10)")

  let row = db.getRow(sql"SELECT x, y FROM asd")
  doAssert(row[0] == "")
  doAssert(row[1] == "10")


proc test_update_hair_color() =
  var ctx = getInMemorySembaCtx()

  let res1 = sembaCall(ctx, "/semba/update_hair_color", %*{
    "charId": 1,
    "r": 0.5,
    "g": 0.5,
    "b": 0.5,
    "enabled": true
  })

  doAssert res1 != nil
  doAssert res1["status"].getStr() == "ok"

  let res2 = sembaCall(ctx, "/semba/update_hair_color", %*{
    "charId": 2,
    "r": 0.5,
    "g": 0.5,
    "b": 0.5,
    "enabled": false
  })

  doAssert res2 != nil
  doAssert res2["status"].getStr() == "ok"

  let res4 = sembaCall(ctx, "/semba/update_hair_color", %*{
    "charId": 2,
    "r": 0.8,
    "g": 0.8,
    "b": 0.8,
    "enabled": false
  })

  doAssert res4 != nil
  doAssert res4["status"].getStr() == "ok"

  let res3 = sembaCall(ctx, "/semba/get_hair_colors", nil)

  doAssert res3 != nil

  let hairColors = to(res3, seq[HairColor])

  doAssert(hairColors.len == 2)

  for hairColor in hairColors:
    doAssert(hairColor.charId == 1 or hairColor.charId == 2)
    if hairColor.charId == 1:
      doAssert(hairColor.enabled)
      doAssert(hairColor.r == 0.5)
      doAssert(hairColor.g == 0.5)
      doAssert(hairColor.b == 0.5)
    else: # hairColor.charId == 2
      doAssert(not hairColor.enabled)
      doAssert(hairColor.r == 0.8)
      doAssert(hairColor.g == 0.8)
      doAssert(hairColor.b == 0.8)


proc test_reward_field_name() =
  let reward = Reward()
  let rewardJson = %*reward
  doAssert rewardJson.hasKey("type")


when isMainModule:
  test_null()

  let retval = test_reset_db()

  test_update_hair_color()

  test_reward_field_name()

  echo("End of test_semba.nim")

  quit(retval)