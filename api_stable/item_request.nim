import std/options
import std/json

import ../model_stable/item_request
import ../model_stable/timestamp


type ItemRequestGetResponse* = object
  itemRequest*: Option[ItemRequest]
  isPublished*: Option[bool]

type ItemRequestListResponse* = object
  itemRequests*: seq[ItemRequest]
  users*: seq[JsonNode] # FIXME: use FollowUser
  deliveryCount*: int

type ItemRequestPublishRequest* = object
  deliveryRequestItemId*: int

type ItemRequestPublishResponse* = object
  itemRequest*: ItemRequest


proc item_request_Get*(): ItemRequestGetResponse =
  discard


proc item_request_List*(): ItemRequestListResponse =
  discard


proc item_request_Publish*(req: ItemRequestPublishRequest): ItemRequestPublishResponse =
  result.itemRequest = ItemRequest(
    userId: 1,
    deliveryRequestItemId: req.deliveryRequestItemId,
    publishedAt: now().timestamp,
  )