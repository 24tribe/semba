import std/options
import std/json
import std/strutils
import system/ansi_c

from db_connector/sqlite3 import libversion_number
import db_connector/db_sqlite

import ./semba/sembastable
import ./semba/sembaprivate
import ./semba/protojson
import ./semba/model_stable/battle
import ./semba/model_stable/timestamp

doAssert(libversionNumber() >= 3_050_004, "sqlite3 version must be >= 3.50.4")

type SembaExGameVersion* = enum
    gameVersion_1_1_3_35 = 0
    gameVersion_0_2_1_20 = 1

type SembaExStatus* = enum 
    statusOk = 0
    statusException = 1
    statusVersionUnknown = 2
    statusDbError = 3
    statusAllocError = 4
    statusInvalidContext = 5


const hasThreadSupport = compileOption("threads")


type SembaExContext* = object
  db*: DbConn
  gameVersion*: SembaExGameVersion
  when hasThreadSupport:
    lastBattleInfo*: cstring
  else:
    lastBattleInfo*: Option[BattleInfo]

type SembaExContextRef* = ref SembaExContext


proc logFlowOffline*(db: DbConn, uri: string, req: string, res: string) =
  db.exec(
    sql"INSERT INTO debugLogsOffline (receivedAt, uri, req, res) VALUES (?, ?, ?, ?)",
    getDateNow(), uri, req, res
  )


proc dupString*(str: string): cstring =
  let s = str.cstring
  result = cast[cstring](c_malloc((s.len + 1).csize_t))
  copyMem(result, s, s.len + 1)


proc sembaExCallImpl*(
  ctx: SembaExContextRef, path: string, request: string
): string =
  let jsonReq = if request != "": parseJson(request) else: nil
  var jsonRes: JsonNode

  ctx.db.exec(sql"BEGIN")

  var committed = false

  var lastBattleInfo =
    when hasThreadSupport:
      if ctx.lastBattleInfo.isNil:
        none(BattleInfo)
      else:
        parseJson($ctx.lastBattleInfo).protoJsonTo(Option[BattleInfo])
    else:
      ctx.lastBattleInfo

  try:
    if path.startsWith("/semba/"):
      jsonRes = getJsonResultPrivateApi(path, jsonReq, ctx.db)
    else:
      jsonRes = getJsonResultStable(path, jsonReq, ctx.db, lastBattleInfo)

    when hasThreadSupport:
      c_free(ctx.lastBattleInfo)
      ctx.lastBattleInfo = dupString($(lastBattleInfo.toProtoJson))
    else:
      ctx.lastBattleInfo = lastBattleInfo

    ctx.db.exec(sql"COMMIT")
    committed = true
  finally:
    if not committed:
      ctx.db.exec(sql"ROLLBACK")

  result = if jsonRes != nil: $jsonRes else: ""

  if not path.startsWith("/auth"):
    logFlowOffline(ctx.db, path, request, result)


proc int32ToGameVersion(gameVersion: int32): Option[SembaExGameVersion] =
    result = case gameVersion
        of ord(gameVersion_1_1_3_35): some(gameVersion_1_1_3_35)
        else: none(SembaExGameVersion)


proc sembaExInit(
    dbPath: cstring, gameVersion: int32, status: ptr int32
): SembaExContextRef {.exportc: "SembaExInit", dynlib.} =
    let version = int32ToGameVersion(gameVersion)

    if version.isNone():
        if status != nil:
            status[] = statusVersionUnknown.int32
        return nil

    var db: DbConn

    try:
        db = open($dbPath, "", "", "")
    except DbError:
        if status != nil:
            status[] = statusDbError.int32
        return nil

    when hasThreadSupport:
      let lastBattleInfo: cstring = nil
    else:
      let lastBattleInfo = none(BattleInfo)

    result = SembaExContextRef(db: db, gameVersion: version.get(), lastBattleInfo: lastBattleInfo)
    GC_ref(result)

    if status != nil:
        status[] = statusOk.int32


proc sembaExCall(
    ctx: SembaExContextRef, path: cstring, req: cstring, status: ptr int32
): cstring {.exportc: "SembaExCall", dynlib.} =
    if ctx == nil:
      if status != nil:
        status[] = statusInvalidContext.int32
      return nil

    try:
        let res = sembaExCallImpl(ctx, $path, $req)
        result = if res != "": dupString(res) else: nil
        if status != nil:
            status[] = statusOk.int32
    except Exception:
        let e = getCurrentException()
        result = dupString(getCurrentExceptionMsg() & "\n" & e.getStackTrace())
        if status != nil:
            status[] = statusException.int32


proc sembaExFreeResponse(response: cstring) {.exportc: "SembaExFreeResponse", dynlib.} =
    c_free(response)


proc sembaExDeinit(ctx: SembaExContextRef) {.exportc: "SembaExDeinit", dynlib.} =
    if ctx != nil:
        close(ctx.db)
        GC_unref(ctx)
