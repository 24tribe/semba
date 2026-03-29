import std/options
import std/json

import ../db_connector/db_sqlite
import ../semba
import ../model_stable/battle


proc initMemoryDb*(): DbConn = open(":memory:", "", "", "")


proc sembaCall*(ctx: var SembaExContext, path: string, body: JsonNode): JsonNode =
  let bodyStr = if body != nil: $body else: ""
  let resultStr = sembaExCallImpl(ctx, path, bodyStr)

  if resultStr != "":
    result = parseJson(resultStr)


proc getInMemorySembaCtx*(): SembaExContext =
  result = SembaExContext(gameVersion: gameVersion_1_1_3_35, db: initMemoryDb(), lastBattleInfo: none(BattleInfo))
  discard sembaCall(result, "/semba/reset_db", nil)


proc loadSaveFile*(ctx: var SembaExContext, saves_dir: string, name: string) =
  discard sembaCall(ctx, "/semba/load_save_file", %*{
    "saves_dir": saves_dir,
    "name": name,
  })