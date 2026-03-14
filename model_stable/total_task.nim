import std/json
import std/strutils

import ../db_connector/db_sqlite


proc addTotalTask*(db: DbConn, totalTask: JsonNode) =
  let conditionId = totalTask["conditionId"].getInt()
  db.exec(sql"INSERT INTO totalTasks (conditionId) VALUES (?)", conditionId)


proc getTotalTasks*(db: DbConn): seq[JsonNode] =
  let totalTasksRows = db.getAllRows(sql"SELECT conditionId FROM totalTasks")
  
  for totalTaskRow in totalTasksRows:
    let conditionId = parseInt(totalTaskRow[0])

    result.add(%*{"conditionId": conditionId})