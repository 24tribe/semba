import std/json

import ../db_connector/db_sqlite

import ../model_stable/mail


proc mail_List*(db: DbConn): JsonNode =
  var bulkMails = newSeq[JsonNode]()
  let opened = getMails(db, #[ opened = ]# true, bulkMails)
  let unopened = getMails(db, #[ opened = ]# false, bulkMails)
  let mailNotification = unopened.len > 0

  result = %*{
    "list": {
      "opened": opened,
      "unopened": unopened,
      "bulkMails": bulkMails
    },
    "changedResources": {
      "notifications": {
        "mail": mailNotification
      }
    }
  }