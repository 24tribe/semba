import std/json

import ../db_connector/db_sqlite

import gacha


proc getNotifications*(db: DbConn): JsonNode =
  let gacha = getGachaNotification(db)
  return %*{
    "gacha": gacha,
    "mail": true,
    "itemRequest": false
  }