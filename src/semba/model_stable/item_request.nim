import std/options

import ../protojson
import timestamp


type ItemRequest* = object
  userId*: ProtoJsonInt64
  deliveryRequestItemId*: int
  publishedAt*: Timestamp
  fulfilledAt*: Option[Timestamp]
  isNew*: Option[bool]