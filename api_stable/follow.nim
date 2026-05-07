import std/json


type FollowListResponse* = object
  users*: seq[JsonNode] # FIXME: use FollowUser


proc follow_List*(): FollowListResponse =
  discard