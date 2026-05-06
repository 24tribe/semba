import std/options

import timestamp


type ItemRequest* = object
  userId*: int64
  deliveryRequestItemId*: int
  publishedAt*: Timestamp
  fullfilledAt*: Option[Timestamp]
  isNew*: Option[bool]