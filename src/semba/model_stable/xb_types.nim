import std/json
import std/options

type XbStatus* = object
  xbId*: int
  actionSequenceId*: Option[int]

type XbMember* = object
  memberId*: Option[int]
  xbBaseCharacterId*: int
  xbCharacterId*: Option[int]
  characterId*: Option[int]
  characterAssetId*: int
  level*: int
  position*: Option[int]
  battingOrder*: Option[int]
  skillIds*: seq[int]
  displayLevel*: string
  maxHp*: Option[int]
  attack*: Option[int]
  defense*: Option[int]
  characterSkillPanelLevels*: seq[int]
  isGuest*: bool
  isDisable*: bool
  isVisible*: bool
  isHologram*: bool

type XbSuggestMember* = object
  index*: int
  memberId*: int
  suggestionId*: int
  skillRank*: int
  
type XbSuggest* = object
  commandId*: int
  members*: seq[XbSuggestMember]

type XbCommandCorrectType* {.pure.} = enum 
  correct_command
  normal_command
  incorrect_command

type XbCommand* = object
  commandId*: int
  xbCharacterWordsId*: int
  isLockingCommand*: bool
  correctType*: XbCommandCorrectType
  predictedScore*: int
  battedBallPredictionId*: Option[int]
  predictedUseSkillOrbIds*: seq[int]

# XbZoneArea.index:
# 2|1|0
# -+-+-
# 5|4|3
# -+-+-
# 8|7|6 
type XbZoneArea* = object
  index*: int
  playerSuggests*: seq[XbSuggest]
  enemySuggests*: seq[XbSuggest]
  commands*: seq[XbCommand]

type XbTeam* = object
  name*: string
  tribeLogoAasPath*: string
  pvpUserInfo*: JsonNode # FIXME: use Option[XbPvPUserInfo]
  members*: seq[XbMember]
  batFirst*: bool
  isPlayerTeam*: bool
  inningScores*: seq[int]
  currentBattingOrder*: int
  zoneAreas*: seq[XbZoneArea]
  defaultZoneAreaIndex*: Option[int]
  selectedCommand*: Option[XbCommand]
  tensionValue*: float
  tensionLv*: int
  isTensionMax*: bool
  blockadeZoneAreaInfo*: JsonNode # FIXME: use XbBlockadeZoneAreaInfo
  skillOrbInfos*: seq[JsonNode] # FIXME: use seq[XbSkillOrbInfo]

type XbGameInfo* = object
  xbId*: int
  index*: int
  topTeam*: XbTeam
  bottomTeam*: XbTeam
  currentAtBatEventInfo*: JsonNode # FIXME: use XbAtBatEventInfo
  xbStoryInfo*: JsonNode # FIXME: use XbStoryInfo
  predictedTensionInfos*: seq[JsonNode] # FIXME: use seq[XbPredictedTensionInfo]
  clientStatus*: JsonNode # FIXME: use XbClientStatus
