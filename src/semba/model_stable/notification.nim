import db_connector/db_sqlite

import gacha


type Notifications* = object
  gacha*: GachaNotification
  mail*: bool
  itemRequest*: bool


proc getNotifications*(db: DbConn): Notifications =
  result.gacha = getGachaNotification(db)