import std/json
import std/strutils

import ../db_connector/db_sqlite


proc getWallet*(db: DbConn): JsonNode =
  let freeGemsRow = db.getRow(sql"SELECT val FROM userData WHERE keyName='freeGems'")
  let freeGems = parseInt(freeGemsRow[0])
  let paidGemsRow = db.getRow(sql"SELECT val FROM userData WHERE keyName='paidGems'")
  let paidGems = parseInt(paidGemsRow[0])
  return %*{
    "free": freeGems,
    "paid": paidGems
  }

proc setWallet*(db: DbConn, wallet: JsonNode) =
  let freeGems = wallet["free"].getInt()
  let paidGems = wallet["paid"].getInt()
  db.exec(sql"UPDATE userData SET val=? WHERE keyName='freeGems'", $freeGems)
  db.exec(sql"UPDATE userData SET val=? WHERE keyName='paidGems'", $paidGems)