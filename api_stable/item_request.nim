import std/options

import ../model_stable/item_request


type ItemRequestGetResponse* = object
  itemRequest: Option[ItemRequest]
  isPublished: Option[bool]


proc item_request_Get*(): ItemRequestGetResponse =
  discard