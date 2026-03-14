import std/json
import std/strutils

import ../db_connector/db_sqlite


proc getMails*(db: DbConn, opened: bool, bulkMails: var seq[JsonNode]): seq[JsonNode] =
  let openedInt = if opened: 1 else: 0

  let rows = db.getAllRows(sql"""
    SELECT entityId, mailType, subject, body, sender, rewards, createdAt, endAt
    FROM mails
    WHERE opened = ?
  """, openedInt)

  for row in rows:
    let entityId = parseInt(row[0])
    let mailType = parseInt(row[1])
    let subject = row[2]
    let body = row[3]
    let sender = row[4]
    let rewards = parseJson(row[5])
    let createdAt = row[6]
    let endAt = row[7]
    let bulkMailId = entityId*1000

    result.add(%*{
      "entityId": entityId,
      "mailType": mailType,
      "mailParams": {
        "bulkMailId": bulkMailId,
      },
      "rewards": rewards,
      "createdAt": createdAt,
      "endAt": endAt
    })

    bulkMails.add(%*{
      "id": bulkMailId,
      "subject": subject,
      "body": body,
      "sender": sender,
    })