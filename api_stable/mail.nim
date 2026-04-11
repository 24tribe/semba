import std/json
import std/options

import ../db_connector/db_sqlite

import ../model_stable/mail
import ../model_stable/resources
import ../model_stable/reward


type MailListResponse = object
  list: MailList
  changedResources: Resources

type MailOpenRequest* = object
  entityIds: seq[int]

type MailOpenResponse* = object
  changedResources: Resources
  rewards: seq[Reward]
  overflowedRewards: seq[Resource]
  list: MailList


proc mail_List*(db: DbConn): MailListResponse =
  let mailList = getMails(db)
  let mailNotification = mailList.unopened.len > 0

  result.list = mailList
  result.changedResources.notifications = some(Notifications(mail: some(mailNotification)))


proc mail_Open*(db: DbConn, req: MailOpenRequest): MailOpenResponse =
  discard