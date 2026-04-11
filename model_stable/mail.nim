import std/json
import std/strutils
import std/options

import ../db_connector/db_sqlite
import reward
import timestamp

type MailType* = enum
  MailInvalid = 0
  MailTemplate = 1
  MailInLine = 2
  MailBulkMail = 3

type MailParams* = object
  mailTemplateId: Option[int]
  subject: Option[string]
  body: Option[string]
  bulkMailId: Option[int]
  sender: Option[string]

type Resource* = object
  `type`*: int
  id*: int
  quantity*: int
  resourceParams*: Option[ResourceParams]

type BulkMail* = object
  id*: int
  subject*: string
  body*: string
  sender*: string

type Mail* = object
  entityId*: int
  mailType*: int
  mailParams*: MailParams
  rewards*: seq[Resource]
  createdAt*: Timestamp
  openedAt*: Option[Timestamp]
  endAt*: Timestamp

type MailList* = object
  unopened*: seq[Mail]
  opened*: seq[Mail]
  bulkMails*: seq[BulkMail]


proc getMails*(db: DbConn): MailList =
  let rows = db.getAllRows(sql"""
    SELECT entityId, mailType, subject, body, sender, rewards, createdAt, endAt, opened
    FROM mails
  """)

  for row in rows:
    let entityId = parseInt(row[0])
    let bulkMailId = entityId*1000

    let mail = Mail(
      entityId: entityId,
      mailType: parseInt(row[1]),
      mailParams: MailParams(
        bulkMailId: some(bulkMailId),
      ),
      rewards: to(parseJson(row[5]), seq[Resource]),
      createdAt: row[6].Timestamp,
      endAt: row[7].Timestamp,
    )

    let opened = parseBool(row[8])

    if opened:
      result.opened.add(mail)
    else:
      result.unopened.add(mail)

    result.bulkMails.add(BulkMail(
      id: bulkMailId,
      subject: row[2],
      body: row[3],
      sender: row[4],
    ))