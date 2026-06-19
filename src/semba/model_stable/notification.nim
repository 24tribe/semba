import db_connector/db_sqlite

import gacha


type Notifications* = object
  gacha*: GachaNotification
  mail*: Option[bool]
  itemRequest*: Option[bool]


proc getNotifications*(db: DbConn): Notifications =
  result.gacha = getGachaNotification(db)