import std/options
import std/sequtils
import std/tables

import db_connector/db_sqlite

import ../model_stable/mail
import ../model_stable/resources
import ../model_stable/reward
import ../model_stable/notification


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

  result.list = mailList
  result.changedResources.notifications = some(Notifications(mail: some(mailList.hasUnopenedMails())))


proc mail_Open*(db: DbConn, req: MailOpenRequest): MailOpenResponse =
  let mails = getMailsWithIds(db, req.entityIds)
  setMailsWithIdsAsOpened(db, req.entityIds)

  var rewards = mails.foldl(a.concat(mailRewardsToProperRewards(db, b.rewards)), newSeq[Reward]())

  var unused: Table[int, int]
  let changedResources = updateResourcesFromRewardsTypeSafe(db, rewards, unused)

  let mailList = getMails(db)

  result.list = mailList
  result.rewards = rewards
  result.changedResources = changedResources
  result.changedResources.notifications = some(Notifications(mail: some(mailList.hasUnopenedMails())))