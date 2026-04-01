import std/options
import std/json

import ../db_connector/db_sqlite

import ../semba
import ../sembaprivate
import ../model_stable/battle
import utils


proc itemsTableExists(db: DbConn): bool =
  result = db.getRow(sql"SELECT name FROM sqlite_schema WHERE name = 'items'")[0] == "items"


proc test_reset_db() =
  var ctx = SembaExContext(gameVersion: gameVersion_1_1_3_35, db: initMemoryDb(), lastBattleInfo: none(BattleInfo))

  doAssert(not itemsTableExists(ctx.db))

  discard sembaCall(ctx, "/semba/reset_db", nil)

  doAssert(itemsTableExists(ctx.db))


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


proc testSuiteSembaPrivate*() =
  test_reset_db()

  test_update_hair_color()