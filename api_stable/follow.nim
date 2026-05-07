import std/json
import std/options


type FollowListResponse* = object
  users*: seq[JsonNode] # FIXME: use FollowUser

type FollowSearchRequest* = object
  userId*: int64

type FollowSearchResponse* = object
  user: Option[JsonNode]


proc follow_List*(): FollowListResponse =
  discard


proc follow_Search*(req: FollowSearchRequest): FollowSearchResponse =
  discard