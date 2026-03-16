import std/options
import std/json
import std/strutils
import system/ansi_c

import db_connector/db_sqlite

import sembastable
import sembademo
import sembacore
import sembaprivate
import model_stable/battle


type SembaExGameVersion* = enum
    gameVersion_1_1_3_35 = 0
    gameVersion_0_2_1_20 = 1

type SembaExStatus* = enum 
    statusOk = 0
    statusException = 1
    statusVersionUnknown = 2
    statusDbError = 3
    statusAllocError = 4

type SembaExContext* = object
  db*: DbConn
  gameVersion: SembaExGameVersion
  lastBattleInfo*: Option[BattleInfo]


proc sembaExCallImpl*(
    ctx: var SembaExContext, path: string, request: string
): string =
  let jsonReq = if request != "": parseJson(request) else: nil
  var jsonRes: JsonNode

  if path.startsWith("/semba/"):
    jsonRes = getJsonResultPrivateApi(path, jsonReq, ctx.db)
  else:
    case ctx.gameVersion
    of gameVersion_0_2_1_20:
        jsonRes = getJsonResultDemo(path, jsonReq, ctx.db)
    of gameVersion_1_1_3_35:
        jsonRes = getJsonResultStable(path, jsonReq, ctx.db, ctx.lastBattleInfo)

  result = if jsonRes != nil: $jsonRes else: ""

  logFlowOffline(ctx.db, path, request, result)


proc int32ToGameVersion(gameVersion: int32): Option[SembaExGameVersion] =
    result = case gameVersion
        of ord(gameVersion_1_1_3_35): some(gameVersion_1_1_3_35)
        else: none(SembaExGameVersion)


proc sembaExInit(
    dbPath: cstring, gameVersion: int32, status: ptr int32
): ptr SembaExContext {.exportc: "SembaExInit", dynlib.} =
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

    result = cast[ptr SembaExContext](c_malloc(sizeof(SembaExContext).csize_t))

    if result == nil:
        if status != nil:
            status[] = statusAllocError.int32
        return nil

    result[] = SembaExContext(db: db, gameVersion: version.get(), lastBattleInfo: none(BattleInfo))


proc sembaExCall(
    ctx: ptr SembaExContext, path: cstring, req: cstring, status: ptr int32
): cstring {.exportc: "SembaExCall", dynlib.} =
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
    close(ctx.db)
    c_free(ctx)