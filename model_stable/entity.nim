import strutils

import ../db_connector/db_sqlite


proc popEntityId*(db: DbConn): int =
  let row = db.getRow(sql"SELECT val FROM userData WHERE keyName='nextEntityId'")
  result = parseInt(row[0])
  db.exec(sql"UPDATE userData SET val=? WHERE keyName='nextEntityId'", $(result + 1))


proc popMailEntityId*(db: DbConn): int =
  let row = db.getRow(sql"SELECT val FROM userData WHERE keyName='nextMailEntityId'")

  result =
    if row[0] != "":
      parseInt(row[0])
    else:
      1

  db.exec(sql"""
    INSERT INTO userData (keyName, val) VALUES ('nextMailEntityId', ?)
    ON CONFLICT (keyName) DO UPDATE SET val = excluded.val
  """, $(result + 1))