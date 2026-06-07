import std/sequtils

import ../db_connector/db_sqlite


type OfflineLog* = object
  receivedAt*: string
  uri*: string
  req*: string
  res*: string


proc addOfflineLog*(db: DbConn, log: OfflineLog) =
  db.exec(
    sql"INSERT INTO debugLogsOffline (receivedAt, uri, req, res) VALUES (?, ?, ?, ?)",
    log.receivedAt, log.uri, log.req, log.res
  )


proc getOfflineLogs*(db: DbConn): seq[OfflineLog] =
  let rows = db.getAllRows(sql"SELECT receivedAt, uri, req, res FROM debugLogsOffline")

  result = rows.mapIt(OfflineLog(receivedAt: it[0], uri: it[1], req: it[2], res: it[3]))