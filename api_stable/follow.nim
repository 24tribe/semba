import std/json
import std/options

import ../protojson
import ../model_stable/follow
import ../model_stable/timestamp
import ../model_stable/user
import ../model_stable/formation


type FollowListResponse* = object
  users*: seq[JsonNode] # FIXME: use FollowUser

type FollowSearchRequest* = object
  userId*: ProtoJsonInt64

type FollowSearchResponse* = object
  user: FollowUser


proc follow_List*(): FollowListResponse =
  discard


proc follow_Search*(req: FollowSearchRequest): FollowSearchResponse =
  FollowSearchResponse(user: FollowUser(
    userId: req.userId,
    loggedInAt: now().timestamp,
    cityId: some(10),
    profile: Profile(name: "Yo Kuronaka9", profileBannerId: 2010011, characterLikabilityScale: 500),
    formation: Formation(number: some(1)),
  ))