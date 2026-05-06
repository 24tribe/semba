import std/options

import timestamp


type ItemRequest* = object
  userId*: int64
  deliveryRequestItemId*: int
  publishedAt*: Timestamp
  fulfilledAt*: Option[Timestamp]
  isNew*: Option[bool]