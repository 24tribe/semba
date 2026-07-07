proc sembaExInit(dbPath: cstring, version: int32, status: var int32): pointer {.importc: "SembaExInit".}
proc sembaExCall(ctx: pointer, path: cstring, req: cstring, status: var int32): cstring {.importc: "SembaExCall".}


proc testBattleInfoIsNotGC() =
  var status: int32
  let ctx = sembaExInit(":memory:", 0, status)
  doAssert(status == 0)

  discard sembaExCall(ctx, "/semba/reset_db", "", status)
  doAssert(status == 0)

  discard sembaExCall(ctx, "/battle/start", """{
     "battleEntryIds":[ 2009457, 2009454 ],
     "lineCharacterIds":[ 101101, 100801, 100201 ],
     "battleTriggers":[ { "triggerIds":[ 100201703, 100201702 ] } ],
     "advantageType":"advantage", "isAttackHit":true,
     "currentLocation":{
        "areaType":1, "direction":6,
        "positionCoordinates":{
           "x":-14.709539,
           "y":0.012497902,
           "z":-2.501064
        },
        "areaKeyId":100201
     },
     "bloodStainLocation":{
        "areaKeyId":100201, "areaType":1,
        "positionCoordinates":{
           "x":-19.748484,
           "y":0.015591897,
           "z":-4.7622533
        }
     }
  }""", status)

  doAssert(status == 0);

  discard sembaExCall(ctx, "/battle/finish", """{
    "characterUpdates": [
      { "characterId": 101101, "hp": 857 },
      { "characterId": 100801, "hp": 817 },
      { "characterId": 100201, "hp": 939 }
    ],
    "battleTaskTopics": [
      { "type": "heal_hp", "count": 65 },
      { "type": "qte", "count": 11 }
    ],
    "encounteredEnemyIds": [ 209104, 209103, 252101, 250101 ],
    "battleTimeSecond": 48,
    "taskConditionResult": {
      "usedSkills": [
        { "characterSkillId": 1011016, "count": 4 },
        { "characterSkillId": 1008016, "count": 4 },
        { "characterSkillId": 1002016, "count": 3 }
      ],
      "enemyStabilityBreaks": [
        { "enemyId": 209103, "count": 1 },
        { "enemyId": 209104, "count": 1 },
        { "enemyId": 250101, "count": 1 },
        { "enemyId": 252101, "count": 1 }
      ]
    }
  }""", status)

  doAssert(status == 0)


proc testSuiteFfi*(savesDir: string) =
  testBattleInfoIsNotGC();
