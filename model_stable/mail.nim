import std/json
import std/strutils
import std/options

import ../db_connector/db_sqlite
import ../extsqlite
import reward
import timestamp
import entity

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


proc bulkMailIdFromEntityId(entityId: int): int = entityId*1000


proc sendMail*(
  db: DbConn, subject, body, sender: string, rewards: openArray[Resource], createdAt, endAt: Timestamp
) =
  let entityId = popMailEntityId(db)
  db.exec(sql"""
    INSERT INTO mails (entityId, mailType, subject, body, sender, rewards, createdAt, endAt, opened)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  """, entityId, MailBulkMail.int, subject, body, sender, $(%*rewards), createdAt, endAt, false)


proc getMails*(db: DbConn): MailList =
  let rows = db.getAllRows(sql"""
    SELECT entityId, mailType, subject, body, sender, rewards, createdAt, endAt, opened
    FROM mails
  """)

  for row in rows:
    let entityId = parseInt(row[0])
    let bulkMailId = bulkMailIdFromEntityId(entityId)

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


proc hasUnopenedMails*(mailList: MailList): bool = mailList.unopened.len > 0


proc getMailsWithIds*(db: DbConn, entityIds: openArray[int]): seq[Mail] =
  let rows = db.getAllRows(sql("""
    SELECT entityId, mailType, rewards, createdAt, endAt
    FROM mails WHERE entityId IN """ & sqlIntTuple(entityIds) & """
  """))

  for row in rows:
    let entityId = parseInt(row[0])
    let mailType = parseInt(row[1])
    let rewards = to(parseJson(row[2]), seq[Resource])
    let createdAt = row[3].Timestamp
    let endAt = row[4].Timestamp

    let bulkMailId = entityId*1000

    result.add(Mail(
      entityId: entityId,
      mailType: mailType,
      mailParams: MailParams(
        bulkMailId: some(bulkMailId),
      ),
      rewards: rewards,
      createdAt: createdAt,
      endAt: endAt,
    ))


proc setMailsWithIdsAsOpened*(db: DbConn, entityIds: openArray[int]) =
  db.exec(sql("UPDATE mails SET opened = true WHERE entityId IN " & sqlIntTuple(entityIds)))


proc mailRewardsToProperRewards*(db: DbConn, rewards: openArray[Resource]): seq[Reward] =
  for reward in rewards:
    result.add(Reward(
      `type`: reward.`type`,
      id: reward.id,
      quantity: reward.quantity,
      resourceParams: reward.resourceParams,
      entityId: if shouldHaveEntityId(reward.`type`.RewardType): some(popEntityId(db)) else: none(int)
    ))