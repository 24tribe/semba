import strutils

import ../db_connector/db_sqlite


proc popEntityId*(db: DbConn): int =
  let row = db.getRow(sql"SELECT val FROM userData WHERE keyName='nextEntityId'")
  result = parseInt(row[0])
  db.exec(sql"UPDATE userData SET val=? WHERE keyName='nextEntityId'", $(result + 1))