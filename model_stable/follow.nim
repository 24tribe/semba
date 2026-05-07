import std/options
import std/json

import ../protojson

import timestamp
import formation


type Profile* = object
  name*: string
  profileBannerId*: int
  profileBadgeIds*: Option[seq[int]]
  characterLikabilityScale*: int

type FollowUser* = object
  userId*: ProtoJsonInt64
  followedAt*: Option[Timestamp]
  flowerMark*: Option[int]
  loggedInAt*: Timestamp
  cityId*: Option[int]
  profile*: Profile
  formation*: Formation
  characters*: seq[JsonNode] # FIXME: use FollowUserCharacter
  tensionCards*: seq[JsonNode] # FIXME: use FollowTensionCard
  isXbPvpFormationInitialized*: Option[bool]
  profileBadgeIds*: Option[seq[int]]