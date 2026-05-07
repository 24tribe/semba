import std/json
import std/options

import ../protojson
import ../model_stable/follow
import ../model_stable/formation
import ../model_stable/resources
import ../model_stable/timestamp
import ../model_stable/user


type FollowListResponse* = object
  users*: seq[JsonNode] # FIXME: use FollowUser

type FollowSearchRequest* = object
  userId*: ProtoJsonInt64

type FollowSearchResponse* = object
  user: FollowUser

type FollowAddRequest* = object
  userId*: ProtoJsonInt64

type FollowAddResponse* = object
  followedAt*: Timestamp
  changedResources*: Resources

type FollowDetailRequest* = object
  userId*: ProtoJsonInt64

type FollowDetailResponse* = object
  characterLikabilities*: seq[JsonNode] # FIXME: use CharacterLikability


proc follow_Add*(req: FollowAddRequest): FollowAddResponse =
  FollowAddResponse(followedAt: now().timestamp)


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


proc follow_Detail*(req: FollowDetailRequest): FollowDetailResponse =
  discard