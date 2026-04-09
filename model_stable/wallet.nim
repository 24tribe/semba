import std/json
import std/strutils
import std/options

import ../db_connector/db_sqlite


type Wallet* = object
  free*: Option[int]
  paid*: Option[int]


proc getWallet*(db: DbConn): Wallet =
  let freeGemsRow = db.getRow(sql"SELECT val FROM userData WHERE keyName='freeGems'")
  var freeGems = parseInt(freeGemsRow[0])
  let paidGemsRow = db.getRow(sql"SELECT val FROM userData WHERE keyName='paidGems'")
  var paidGems = parseInt(paidGemsRow[0])
  
  if freeGems >= 5_000_000:
    freeGems = 4_000_000

  if paidGems >= 5_000_000:
    paidGems = 4_000_000

  result = Wallet(free: some(freeGems), paid: some(paidGems))


proc setWallet*(db: DbConn, wallet: Wallet) =
  db.exec(sql"UPDATE userData SET val=? WHERE keyName='freeGems'", wallet.free.get(0))
  db.exec(sql"UPDATE userData SET val=? WHERE keyName='paidGems'", wallet.paid.get(0))