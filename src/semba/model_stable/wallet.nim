import std/strutils

import db_connector/db_sqlite


type Wallet* = object
  free*: int
  paid*: int


proc getWallet*(db: DbConn): Wallet =
  let freeGemsRow = db.getRow(sql"SELECT val FROM userData WHERE keyName='freeGems'")
  var freeGems = parseInt(freeGemsRow[0])
  let paidGemsRow = db.getRow(sql"SELECT val FROM userData WHERE keyName='paidGems'")
  var paidGems = parseInt(paidGemsRow[0])
  
  if freeGems >= 5_000_000:
    freeGems = 4_000_000

  if paidGems >= 5_000_000:
    paidGems = 4_000_000

  result = Wallet(free: freeGems, paid: paidGems)


proc setWallet*(db: DbConn, wallet: Wallet) =
  db.exec(sql"UPDATE userData SET val=? WHERE keyName='freeGems'", wallet.free)
  db.exec(sql"UPDATE userData SET val=? WHERE keyName='paidGems'", wallet.paid)
