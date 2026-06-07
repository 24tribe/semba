import std/strutils
import std/tables
import std/options

import ../db_connector/db_sqlite


type Item* = object
  itemId*: int
  quantity*: Option[int]

type ConsumedItem* = Item


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
  """, item.itemId, item.quantity.get(0))

proc updateItems*(db: DbConn, items: seq[Item]) =
  for item in items:
    upsertItem(db, item)


proc getItems*(db: DbConn): seq[Item] =
  let rows = db.getAllRows(sql(selectItemsSql))

  for row in rows:
    result.add(Item(
      itemId: parseInt(row[0]), quantity: some(parseInt(row[1]))
    ))


proc getItemsTable*(db: DbConn): Table[int, Item] =
  let rows = db.getAllRows(sql(selectItemsSql))

  for row in rows:
    let item = Item(itemId: parseInt(row[0]), quantity: some(parseInt(row[1])))
    result[item.itemId] = item


proc getItem*(db: DbConn, itemId: int): Option[Item] =
  let row = db.getRow(sql"SELECT quantity FROM items WHERE itemId = ?", itemId)

  if row[0] != "":
    result = some(Item(
      itemId: itemId,
      quantity: some(parseInt(row[0]))
    ))


proc calcLifeDataExp*(consumedItems: openArray[ConsumedItem]): int =
  for item in consumedItems:
    case item.itemId:
    of lifeDataId:
      result += item.quantity.get(0)*lifeDataExp
    of goodLifeDataId:
      result += item.quantity.get(0)*goodLifeDataExp
    of greatLifeDataId:
      result += item.quantity.get(0)*greatLifeDataExp
    else:
      echo("WARNING: item.id=" & $item.itemId & " is not a life data!")