import std/json
import std/strutils
import std/tables

import ../db_connector/db_sqlite


const selectItemsSql = "SELECT itemId, quantity FROM items"

proc addItem*(db: DbConn, item: JsonNode) =
  let itemId = item["itemId"].getInt()
  let quantity = item.getOrDefault("quantity").getInt()

  db.exec(sql"""
    INSERT INTO items (itemId, quantity) VALUES (?, ?)
    ON CONFLICT DO
    UPDATE SET quantity = excluded.quantity
  """, itemId, quantity)

proc updateItems*(db: DbConn, items: seq[JsonNode]) =
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