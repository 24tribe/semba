import std/options
import std/strutils
import std/json
import std/sequtils

import db_connector/sqlite3

import ./model_stable/timestamp


type ExtSqliteError = object of CatchableError


proc loadSql*(db: PSqlite3, sql: string) =
    var err: cstring = nil

    discard exec(db, sql.cstring, nil, nil, err)

    if err != nil:
        let errStr = $err
        sqlite3.free(err)
        raise newException(ExtSqliteError, "loadSql failed: " & errStr)


proc optionToSqlArg*[T](val: Option[T]): string =
    if val.isSome(): $val.get() else: ""


proc tryParseInt*(s: string): Option[int] = (if s != "": some(parseInt(s)) else: none(int))

proc tryParseBool*(s: string): Option[bool] = (if s != "": some(parseBool(s)) else: none(bool))

proc tryParseFloat*(s: string): Option[float] = (if s != "": some(parseFloat(s)) else: none(float))

proc tryParseJson*(s: string): Option[JsonNode] = (if s != "": some(parseJson(s)) else: none(JsonNode))

proc tryParseTimestamp*(s: string): Option[Timestamp] = (if s != "": some(s.Timestamp) else: none(Timestamp))

proc sqlIntTuple*(values: openArray[int]): string = "(" & values.mapIt($it).join(",") & ")"