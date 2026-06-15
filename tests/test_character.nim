import std/assertions
import std/algorithm
import std/json
import std/options
import std/sequtils

import ../protojson
import ../model_stable/resources
import ../model_stable/character
import ../model_stable/gear
import ../model_stable/timestamp
import ../model_stable/status
import ../model_stable/item
import utils

const yoCharId = 100101
const irohaCharId = 100201
const koishiCharId = 100501

proc testCharacterStatsDependOnLevel() =
  var ctx = getInMemorySembaCtx()

  const yoLevel2MaxHp = 511
  const yoLevel2Attack = 106
  const yoLevel2Defense = 105
  const yoLevel2Exp = 240

  proc checkYo(character: Character): bool =
    result = character.characterId == yoCharId and
      character.exp == yoLevel2Exp and
      character.maxHp == yoLevel2MaxHp and
      character.attack == yoLevel2Attack and
      character.defense == yoLevel2Defense

  const irohaLevel1MaxHp = 452
  const irohaLevel1Attack = 109
  const irohaLevel1Defense = 92
  const irohaLevel1Exp = 0

  proc checkIroha(character: Character): bool =
    result = character.characterId == irohaCharId and
      character.exp == irohaLevel1Exp and
      character.maxHp == irohaLevel1MaxHp and
      character.attack == irohaLevel1Attack and
      character.defense == irohaLevel1Defense

  setCharacterExp(ctx.db, irohaCharId, irohaLevel1Exp)
  setCharacterExp(ctx.db, yoCharId, yoLevel2Exp)

  let yoChar = getCharacter(ctx.db, yoCharId)
  doAssert(checkYo(yoChar))

  let irohaChar = getCharacter(ctx.db, irohaCharId)
  doAssert(checkIroha(irohaChar))

  let characters = getCharactersTypeSafe(ctx.db)
  doAssert(characters.any(checkYo))
  doAssert(characters.any(checkIroha))


proc testCharacterEquip() =
  var ctx = getInMemorySembaCtx()

  let gearId = 10000

  addGear(ctx.db, Gear(
    entityId: 10000,
    gearId: 10001101,
    receivedAt: getTimestampNow(),
    rarity: gearRarityN.int,
    trainingScoreLevelScore: some(1),
  ))

  let res = ctx.sembaCall("/character/equip", %*{ "characterId": 101101, "gearSlot3": gearId })

  doAssert(res != nil)

  let crRes = protoJsonTo(res, ChangedResourcesResponse)

  let characters = crRes.changedResources.characters

  doAssert(characters.len == 1)
  doAssert(characters[0].gearSlot1.isNone())
  doAssert(characters[0].gearSlot2.isNone())
  doAssert(characters[0].gearSlot3.get() == gearId)

  let res2 = ctx.sembaCall("/character/equip", %*{ "characterId": 101101 })

  let crRes2 = protoJsonTo(res2, ChangedResourcesResponse)

  let characters2 = crRes2.changedResources.characters

  doAssert(characters2.len == 1)
  doAssert(characters2[0].gearSlot1.isNone())
  doAssert(characters2[0].gearSlot2.isNone())
  doAssert(characters2[0].gearSlot3.isNone())


proc checkStats(original: Character, newChar: Character) =
  doAssert(original.exp == newChar.exp)
  doAssert(original.attack == newChar.attack)
  doAssert(original.defense == newChar.defense)
  doAssert(original.maxHp == newChar.maxHp)
  doAssert(original.criticalRate == newChar.criticalRate)
  doAssert(original.criticalDamageRate == newChar.criticalDamageRate)
  doAssert(original.supportPowerRate == newChar.supportPowerRate)
  doAssert(original.recoveryGivenRate == newChar.recoveryGivenRate)


proc testCharacterGearStats() =
  var ctx = getInMemorySembaCtx()

  let gears = protoJsonTo(%*[{
    "entityId": 1, "gearId": 10001101, "receivedAt": "2025-10-13T20:51:23Z",
    "subStatus1Id": 10041001, "subStatus2Id": 10020002,
    "trainingScoreLevelScore": 1, "rarity": 3
  }, {
    "entityId": 2, "gearId": 10001101, "receivedAt": "2025-10-13T20:53:54Z",
    "subStatus1Id": 10081001, "subStatus2Id": 10010001,
    "trainingScoreLevelScore": 1, "rarity": 3
  }, {
    "entityId": 3, "gearId": 30001201, "receivedAt": "2025-10-13T20:55:32Z",
    "subStatus1Id": 10080001, "subStatus2Id": 10098001,
    "trainingScoreLevelScore": 1, "rarity": 3
  }, {
    "entityId": 5, "gearId": 30001101, "receivedAt": "2025-10-13T21:02:51Z",
    "subStatus1Id": 10060002, "subStatus2Id": 10050001,
    "trainingScoreLevelScore": 1, "rarity": 3
  }, {
    "entityId": 6, "gearId": 20001201, "receivedAt": "2025-10-13T21:05:48Z",
    "subStatus1Id": 11012003, "subStatus2Id": 10060002, "subStatus3Id": 10010001,
    "trainingScoreLevelScore": 1, "rarity": 4
  }, {
    "entityId": 7, "gearId": 30001001, "receivedAt": "2025-10-13T21:06:47Z",
    "subStatus1Id": 11006004, "subStatus2Id": 10061002, "subStatus3Id": 10050001,
    "trainingScoreLevelScore": 1, "rarity": 4
  }], seq[Gear])

  for gear in gears:
    addGear(ctx.db, gear)

  var yo = getCharacter(ctx.db, yoCharId)
  yo.exp = 2797
  yo.gearSlot2 = some(2)
  yo.gearSlot3 = some(6)

  var iroha = getCharacter(ctx.db, irohaCharId)
  iroha.exp = 2745
  iroha.gearSlot1 = some(7)
  iroha.gearSlot2 = some(1)
  iroha.gearSlot3 = some(3)

  var koishi = getCharacter(ctx.db, koishiCharId)
  koishi.exp = 2745
  koishi.gearSlot2 = some(5)

  updateCharacters(ctx.db, @[%*yo, %*iroha, %*koishi])

  yo.attack = 147
  yo.defense = 125
  yo.maxHp = 836
  yo.criticalDamageRate = 70.0
  yo.recoveryGivenRate = 8.33

  iroha.attack = 175
  iroha.defense = 135
  iroha.maxHp = 666
  iroha.criticalRate = 9.5
  iroha.criticalDamageRate = 80.0
  iroha.supportPowerRate = 17
  iroha.recoveryGivenRate = 35.0

  koishi.attack = 100
  koishi.defense = 141
  koishi.maxHp = 786
  koishi.criticalRate = 9.5
  koishi.criticalDamageRate = 70.0

  let yoNew = getCharacter(ctx.db, yoCharId)
  checkStats(yo, yoNew)

  let irohaNew = getCharacter(ctx.db, irohaCharId)
  checkStats(iroha, irohaNew)

  let koishiNew = getCharacter(ctx.db, koishiCharId)
  checkStats(koishi, koishiNew)


proc testCharacterEnhance() =
  var ctx = getInMemorySembaCtx()

  const level10MinExp = 4856
  const grossExp = 18500

  let consumedItems = [
    Item(itemId: lifeDataId, quantity: 2),
    Item(itemId: goodLifeDataId, quantity: 3),
    Item(itemId: greatLifeDataId, quantity: 2),
  ]

  for item in consumedItems:
    upsertItem(ctx.db, item)

  var status = getUserStatusTypeSafe(ctx.db)
  status.gold = 2*grossExp + 100
  setUserStatusTypeSafe(ctx.db, status)

  let res = protoJsonTo(sembaCall(ctx, "/character/enhance", %*{
    "characterId": irohaCharId,
    "consumedItems": consumedItems
  }), Option[ChangedResourcesResponse])

  doAssert(calcLifeDataExp(consumedItems) == grossExp)

  doAssert(res.isSome())

  var changedResources = res.get().changedResources

  doAssert(changedResources.characters.len == 1)
  doAssert(changedResources.characters[0].exp == level10MinExp)

  let ld = getItem(ctx.db, lifeDataId)
  doAssert(ld.isSome() and ld.get().quantity == 0)

  let goodLd = getItem(ctx.db, goodLifeDataId)
  doAssert(goodLd.isSome() and goodLd.get().quantity == 0)

  let greatLd = getItem(ctx.db, greatLifeDataId)
  doAssert(greatLd.isSome() and greatLd.get().quantity == 0)

  doAssert(getUserStatusTypeSafe(ctx.db).gold == 100)

  changedResources.items.sort(proc (x1, x2: Item): int = cmp(x1.itemId, x2.itemId))
  doAssert(changedResources.items == @[
    Item(itemId: lifeDataId, quantity: 0),
    Item(itemId: goodLifeDataId, quantity: 0),
    Item(itemId: greatLifeDataId, quantity: 0),
  ])


proc testSuiteCharacter*() =
  testCharacterEquip()
  testCharacterStatsDependOnLevel()
  testCharacterGearStats()
  testCharacterEnhance()