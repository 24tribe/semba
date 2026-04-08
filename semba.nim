import std/options
import std/json
import std/strutils
import system/ansi_c

import db_connector/db_sqlite

import sembastable
import sembademo
import sembaprivate
import model_stable/battle
import model_stable/timestamp

{.compile("NimInit.c", "-O3").}

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

type SembaExContext* = object
  db*: DbConn
  gameVersion*: SembaExGameVersion
  lastBattleInfo*: Option[BattleInfo]


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
    ctx: var SembaExContext, path: string, request: string
): string =
  let jsonReq = if request != "": parseJson(request) else: nil
  var jsonRes: JsonNode

  ctx.db.exec(sql"BEGIN")

  var committed = false

  try:
    if path.startsWith("/semba/"):
      jsonRes = getJsonResultPrivateApi(path, jsonReq, ctx.db)
    else:
      case ctx.gameVersion
      of gameVersion_0_2_1_20:
          jsonRes = getJsonResultDemo(path, jsonReq, ctx.db)
      of gameVersion_1_1_3_35:
          jsonRes = getJsonResultStable(path, jsonReq, ctx.db, ctx.lastBattleInfo)

    ctx.db.exec(sql"COMMIT")
    committed = true
  finally:
    if not committed:
      ctx.db.exec(sql"ROLLBACK")

  result = if jsonRes != nil: $jsonRes else: ""

  logFlowOffline(ctx.db, path, request, result)


proc int32ToGameVersion(gameVersion: int32): Option[SembaExGameVersion] =
    result = case gameVersion
        of ord(gameVersion_1_1_3_35): some(gameVersion_1_1_3_35)
        else: none(SembaExGameVersion)


proc sembaExInit(
    dbPath: cstring, gameVersion: int32, status: ptr int32
): ptr SembaExContext {.exportc: "SembaExInit", dynlib.} =
    echo("Inside sembaExInit")

    let version = int32ToGameVersion(gameVersion)

    echo("After int32ToGameVersion")

    if version.isNone():
        if status != nil:
            status[] = statusVersionUnknown.int32
        return nil

    var db: DbConn

    echo("Trying to open db...")

    try:
        db = open($dbPath, "", "", "")
    except DbError:
        if status != nil:
            status[] = statusDbError.int32
        return nil

    echo("Allocating SembaExContext...")

    result = cast[ptr SembaExContext](c_malloc(sizeof(SembaExContext).csize_t))

    if result == nil:
        if status != nil:
            status[] = statusAllocError.int32
        return nil

    zeroMem(result, sizeof(SembaExContext))

    echo("Creating SembaExContext...")

    result[] = SembaExContext(db: db, gameVersion: version.get(), lastBattleInfo: none(BattleInfo))

    if status != nil:
        status[] = statusOk.int32

    echo("End sembaExInit...")


proc sembaExCall(
    ctx: ptr SembaExContext, path: cstring, req: cstring, status: ptr int32
): cstring {.exportc: "SembaExCall", dynlib.} =
    if ctx == nil:
      if status != nil:
        status[] = statusInvalidContext.int32
      return nil

    try:
        let res = sembaExCallImpl(ctx[], $path, $req)
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


proc sembaExDeinit(ctx: ptr SembaExContext) {.exportc: "SembaExDeinit", dynlib.} =
    if ctx != nil:
        close(ctx.db)
    c_free(ctx)