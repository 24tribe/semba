import std/json
import std/strutils
import std/options
import system/ansi_c

import db_connector/db_sqlite

import sembastable
import sembademo
import sembaprivate
import model_stable/timestamp
import model_stable/battle

export sembastable


type GameVersion* = enum
  gvNone, gvStable, gvDemo, gvBeta


proc dupString*(str: string): cstring =
  let s = str.cstring
  result = cast[cstring](c_malloc((s.len + 1).csize_t))
  copyMem(result, s, s.len + 1)


proc logFlowOffline*(db: DbConn, uri: string, req: string, res: string) =
  db.exec(
    sql"INSERT INTO debugLogsOffline (receivedAt, uri, req, res) VALUES (?, ?, ?, ?)",
    getDateNow(), uri, req, res
  )


proc sembaCallImpl*(
    uri: string, request: string, version: GameVersion,
    db: DbConn, lastBattleInfo: var Option[BattleInfo]
): string =
  let jsonReq = if request != "": parseJson(request) else: nil
  var jsonRes: JsonNode

  if uri.startsWith("/semba/"):
    jsonRes = getJsonResultPrivateApi(uri, jsonReq, db)
  elif version == gvDemo:
    jsonRes = getJsonResultDemo(uri, jsonReq, db)
  else:
    jsonRes = getJsonResultStable(uri, jsonReq, db, lastBattleInfo)

  result = if jsonRes != nil: $jsonRes else: ""

  logFlowOffline(db, uri, request, result)