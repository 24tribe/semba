import std/json
import std/options

import ../db_connector/db_sqlite

import ../model_stable/mail
import ../model_stable/resources


type MailListResponse = object
  list: MailList
  changedResources: Resources


proc mail_List*(db: DbConn): MailListResponse =
  let mailList = getMails(db)
  let mailNotification = mailList.unopened.len > 0

  result.list = mailList
  result.changedResources.notifications = some(Notifications(mail: some(mailNotification)))