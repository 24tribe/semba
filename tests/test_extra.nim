import std/assertions

import ../db_connector/db_sqlite
import utils

proc test_null() =
  let db = initMemoryDb()
  db.exec(sql"CREATE TABLE asd (x INTEGER, y INTEGER)")
  db.exec(sql"INSERT INTO asd (x, y) VALUES (null, 10)")

  let row = db.getRow(sql"SELECT x, y FROM asd")
  doAssert(row[0] == "")
  doAssert(row[1] == "10")


proc test_bool_is_not_zero_or_one() =
  let db = initMemoryDb()
  db.exec(sql"CREATE TABLE asd (x BOOLEAN)")
  db.exec(sql"INSERT INTO asd (x) VALUES (?)", true)

  let row = db.getRow(sql"SELECT x FROM asd")
  doAssert(row[0] == "true")


when isMainModule:
  test_null()
  test_bool_is_not_zero_or_one()