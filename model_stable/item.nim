import std/strutils
import std/tables
import std/options
import std/sequtils
import std/sugar

import ../db_connector/db_sqlite

import ../extsqlite


type Item* = object
  itemId*: int
  quantity*: int

type ConsumedItem* = Item


const tcExpItemId* = 2

const lifeDataId* = 3
const lifeDataExp* = 500

const goodLifeDataId* = 4
const goodLifeDataExp* = 2500

const greatLifeDataId* = 5
const greatLifeDataExp* = 5000

const selectItemsSql = "SELECT itemId, quantity FROM items"

proc upsertItem*(db: DbConn, item: Item) =
  db.exec(sql"""
    INSERT INTO items (itemId, quantity) VALUES (?, ?)
    ON CONFLICT DO
    UPDATE SET quantity = excluded.quantity
  """, item.itemId, item.quantity)

proc updateItems*(db: DbConn, items: openArray[Item]) =
  for item in items:
    upsertItem(db, item)


proc getItems*(db: DbConn): seq[Item] =
  let rows = db.getAllRows(sql(selectItemsSql))

  for row in rows:
    result.add(Item(
      itemId: parseInt(row[0]), quantity: parseInt(row[1])
    ))


proc getItemsTable*(db: DbConn): Table[int, Item] =
  let rows = db.getAllRows(sql(selectItemsSql))

  for row in rows:
    let item = Item(itemId: parseInt(row[0]), quantity: parseInt(row[1]))
    result[item.itemId] = item


proc getItem*(db: DbConn, itemId: int): Option[Item] =
  let row = db.getRow(sql"SELECT quantity FROM items WHERE itemId = ?", itemId)

  if row[0] != "":
    result = some(Item(
      itemId: itemId,
      quantity: parseInt(row[0]),
    ))


proc calcLifeDataExp*(consumedItems: openArray[ConsumedItem]): int =
  for item in consumedItems:
    case item.itemId:
    of lifeDataId:
      result += item.quantity*lifeDataExp
    of goodLifeDataId:
      result += item.quantity*goodLifeDataExp
    of greatLifeDataId:
      result += item.quantity*greatLifeDataExp
    else:
      echo("WARNING: item.id=" & $item.itemId & " is not a life data!")


proc addCountsToItems*(db: DbConn, itemCounts: Table[int, int]): seq[Item] =
  ## Gets the item quantities in the db and adds `itemCounts` values to them.
  ## Returns the changed items. Doesn't update the db.

  let currentItemCounts = db.getAllRows(sql("""
    SELECT itemId, quantity FROM items WHERE itemId IN """ & sqlIntTuple(itemCounts.keys.toSeq)
  )).mapIt((parseInt(it[0]), parseInt(it[1]))).toTable

  result = collect:
    for itemId, quantity in itemCounts.pairs:
      Item(itemId: itemId, quantity: quantity + currentItemCounts.getOrDefault(itemId))