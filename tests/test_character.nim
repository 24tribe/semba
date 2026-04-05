import std/assertions
import std/json
import std/options
import std/sequtils

import ../model_stable/resources
import ../model_stable/character
import ../model_stable/gear
import ../model_stable/timestamp
import ../model_stable/item
import ../model_stable/user
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
      character.exp.get(0) == yoLevel2Exp and
      character.maxHp.get(0) == yoLevel2MaxHp and
      character.attack.get(0) == yoLevel2Attack and
      character.defense.get(0) == yoLevel2Defense

  const irohaLevel1MaxHp = 452
  const irohaLevel1Attack = 109
  const irohaLevel1Defense = 92
  const irohaLevel1Exp = 0

  proc checkIroha(character: Character): bool =
    result = character.characterId == irohaCharId and
      character.exp.get(0) == irohaLevel1Exp and
      character.maxHp.get(0) == irohaLevel1MaxHp and
      character.attack.get(0) == irohaLevel1Attack and
      character.defense.get(0) == irohaLevel1Defense

  setCharacterExp(ctx.db, irohaCharId, irohaLevel1Exp)
  setCharacterExp(ctx.db, yoCharId, yoLevel2Exp)

  let yoChar = getCharacter(ctx.db, yoCharId)
  doAssert(checkYo(yoChar))

  let irohaChar = getCharacter(ctx.db, irohaCharId)
  doAssert(checkIroha(irohaChar))

  let characters = to(%*getCharacters(ctx.db), seq[Character])
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

  let crRes = to(res, ChangedResourcesResponse)

  let characters = to(%*(crRes.changedResources.characters.get()), seq[Character])

  doAssert(characters.len == 1)
  doAssert(characters[0].gearSlot1.isNone())
  doAssert(characters[0].gearSlot2.isNone())
  doAssert(characters[0].gearSlot3.get() == gearId)

  let res2 = ctx.sembaCall("/character/equip", %*{ "characterId": 101101 })

  let crRes2 = to(res2, ChangedResourcesResponse)

  let characters2 = to(%*(crRes2.changedResources.characters.get()), seq[Character])

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
  doAssert(original.supportPowerRate.get(0) == newChar.supportPowerRate.get(0))
  doAssert(original.recoveryGivenRate.get(0) == newChar.recoveryGivenRate.get(0))


proc testCharacterGearStats() =
  var ctx = getInMemorySembaCtx()

  let gears = to(%*[{
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
  yo.exp = some(2797)
  yo.gearSlot2 = some(2)
  yo.gearSlot3 = some(6)

  var iroha = getCharacter(ctx.db, irohaCharId)
  iroha.exp = some(2745)
  iroha.gearSlot1 = some(7)
  iroha.gearSlot2 = some(1)
  iroha.gearSlot3 = some(3)

  var koishi = getCharacter(ctx.db, koishiCharId)
  koishi.exp = some(2745)
  koishi.gearSlot2 = some(5)

  updateCharacters(ctx.db, @[%*yo, %*iroha, %*koishi])

  yo.attack = some(147)
  yo.defense = some(125)
  yo.maxHp = some(836)
  yo.criticalDamageRate = some(70.0)
  yo.recoveryGivenRate = some(8.33)

  iroha.attack = some(175)
  iroha.defense = some(135)
  iroha.maxHp = some(666)
  iroha.criticalRate = some(9.5)
  iroha.criticalDamageRate = some(80.0)
  iroha.supportPowerRate = some(17)
  iroha.recoveryGivenRate = some(35.0)

  koishi.attack = some(100)
  koishi.defense = some(141)
  koishi.maxHp = some(786)
  koishi.criticalRate = some(9.5)
  koishi.criticalDamageRate = some(70.0)

  let yoNew = getCharacter(ctx.db, yoCharId)
  checkStats(yo, yoNew)

  let irohaNew = getCharacter(ctx.db, irohaCharId)
  checkStats(iroha, irohaNew)

  let koishiNew = getCharacter(ctx.db, koishiCharId)
  checkStats(koishi, koishiNew)


proc testCharacterEnhance() =
  var ctx = getInMemorySembaCtx()

  addItem(ctx.db, Item(itemId: lifeDataId, quantity: some(2)))
  addItem(ctx.db, Item(itemId: goodLifeDataId, quantity: some(3)))
  addItem(ctx.db, Item(itemId: greatLifeDataId, quantity: some(2)))

  const expReceived = 18500

  let status = getUserStatus(ctx.db)
  status["gold"] = %*(2*expReceived + 100)
  setUserStatus(ctx.db, status)

  let iroha = getCharacter(ctx.db, irohaCharId)

  let res = to(sembaCall(ctx, "/character/enhance", %*{
    "characterId": irohaCharId,
    "consumedItems": [
      {"itemId": lifeDataId, "quantity": 2},
      {"itemId": goodLifeDataId, "quantity": 3},
      {"itemId": greatLifeDataId, "quantity": 2},
    ]
  }), Option[ChangedResourcesResponse])

  doAssert(res.isSome())

  let changedResources = res.get().changedResources

  let characters = changedResources.characters.get(@[])
  doAssert(characters.len == 1)
  doAssert(characters[0].exp.get(0) == iroha.exp.get(0) + expReceived)

  let ld = getItem(ctx.db, lifeDataId)
  doAssert(ld.isSome() and ld.get().quantity.get(0) == 0)

  let goodLd = getItem(ctx.db, goodLifeDataId)
  doAssert(goodLd.isSome() and goodLd.get().quantity.get(0) == 0)

  let greatLd = getItem(ctx.db, greatLifeDataId)
  doAssert(greatLd.isSome() and greatLd.get().quantity.get(0) == 0)

  doAssert(getUserStatus(ctx.db)["gold"].getInt() == 100)


proc testSuiteCharacter*() =
  testCharacterEquip()
  testCharacterStatsDependOnLevel()
  testCharacterGearStats()
  testCharacterEnhance()