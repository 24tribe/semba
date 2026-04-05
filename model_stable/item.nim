import std/json
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

proc addItem*(db: DbConn, item: Item) =
  db.exec(sql"""
    INSERT INTO items (itemId, quantity) VALUES (?, ?)
    ON CONFLICT DO
    UPDATE SET quantity = excluded.quantity
  """, item.itemId, item.quantity.get(0))

proc updateItems*(db: DbConn, items: seq[Item]) =
  for item in items:
    addItem(db, item)

proc parseItemRow(row: Row): JsonNode =
  let itemId = parseInt(row[0])
  let quantity = parseInt(row[1])

  result = %*{
    "itemId": itemId,
    "quantity": quantity,
  }

proc getItems*(db: DbConn): seq[JsonNode] =
  let rows = db.getAllRows(sql(selectItemsSql))

  for row in rows:
    let item = parseItemRow(row)
    result.add(item)

proc getItemsTable*(db: DbConn): Table[int, JsonNode] =
  let rows = db.getAllRows(sql(selectItemsSql))

  for row in rows:
    let item = parseItemRow(row)
    result[item["itemId"].getInt()] = item

proc itemsTableToItemsSeq*(itemsTable: Table[int, JsonNode]): seq[JsonNode] =
  for item in itemsTable.values():
    result.add(item)


proc getItem*(db: DbConn, itemId: int): Option[Item] =
  let row = db.getRow(sql"SELECT quantity FROM items WHERE itemId = ?", itemId)

  if row[0] != "":
    result = some(Item(
      itemId: itemId,
      quantity: some(parseInt(row[0]))
    ))