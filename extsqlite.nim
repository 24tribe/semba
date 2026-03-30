import std/options
import std/strutils

import db_connector/sqlite3

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