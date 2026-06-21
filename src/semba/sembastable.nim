import std/json
import std/options

import db_connector/db_sqlite

import ./api_stable/adventure
import ./api_stable/battle
import ./api_stable/character
import ./api_stable/dungeon
import ./api_stable/event
import ./api_stable/follow
import ./api_stable/formation
import ./api_stable/gacha
import ./api_stable/happy_worker
import ./api_stable/item_request
import ./api_stable/mail
import ./api_stable/mission
import ./api_stable/news
import ./api_stable/purchase
import ./api_stable/shop
import ./api_stable/tension_card
import ./api_stable/tip
import ./api_stable/user
import ./api_stable/xb
import ./model_stable/battle
import ./protojson


proc getJsonResultStable*(
  uri: string, jsonReq: JsonNode,
  db: DbConn, lastBattleInfo: var Option[BattleInfo]
): JsonNode =
  case uri:
  of "/adventure/area_object":
    result = toProtoJson(adventure_AreaObject(db, jsonReq))
  of "/adventure/find_graffiti":
    result = toProtoJson(adventure_FindGraffiti(db, protoJsonTo(jsonReq, AdventureFindGraffitiRequest)))
  of "/adventure/move_to_area":
    result = toProtoJson(adventure_MoveToArea(db, protoJsonTo(jsonReq, AdventureMoveToAreaRequest)))
  of "/adventure/update_character_status":
    result = toProtoJson(adventure_UpdateCharacterStatus(db, jsonReq))
  of "/adventure/read_sequence":
    result = toProtoJson(adventure_ReadSequence(db, protoJsonTo(jsonReq, AdventureReadSequenceRequest)))
  of "/adventure/acquire_area_item":
    result = toProtoJson(adventure_AcquireAreaItem(db, protoJsonTo(jsonReq, AdventureAcquireAreaItemRequest)))
  of "/adventure/release_event_lift":
    result = adventure_ReleaseEventLift(jsonReq)
  of "/adventure/warp_area_locator":
    result = toProtoJson(adventure_WarpAreaLocator(db, jsonReq))
  of "/adventure/hospital":
    result = toProtoJson(adventure_Hospital(db))
  of "/adventure/access_warp_point":
    result = toProtoJson(adventure_AccessWarpPoint(db, jsonReq))

  of "/auth/steam_user":
    result = %*{"userId": 696969696969}
  of "/auth/nonce":
    result = %*{"nonce": "6969696969696969"}
  of "/auth/sign_in":
    result = %*{"sessionToken": "69696969-6969-6969-6969-696969696969", "language": 2}

  of "/battle/start":
    result = toProtoJson(battle_Start(db, lastBattleInfo, jsonReq))
  of "/battle/finish":
    result = toProtoJson(battle_Finish(db, lastBattleInfo, protoJsonTo(jsonReq, BattleFinishRequest)))
  of "/battle/restart":
    result = toProtoJson(battle_Restart(db, lastBattleInfo, protoJsonTo(jsonReq, BattleRestartRequest)))
  of "/battle/skip":
    result = battle_Skip(db, jsonReq.protoJsonTo(BattleSkipRequest)).toProtoJson

  of "/character/costume_update":
    result = toProtoJson(character_CostumeUpdate(db, jsonReq))
  of "/character/limit_break":
    result = toProtoJson(character_LimitBreak(db, jsonReq))
  of "/character/equip":
    result = toProtoJson(character_Equip(db, protoJsonTo(jsonReq, CharacterEquipRequest)))
  of "/character/enhance":
    result = toProtoJson(character_Enhance(db, protoJsonTo(jsonReq, CharacterEnhanceRequest)))

  of "/dungeon/acquire_area_item":
    result = dungeon_AcquireAreaItem(db, jsonReq.protoJsonTo(DungeonAcquireAreaItemRequest)).toProtoJson
  of "/dungeon/entry":
    result = dungeon_Entry(db, jsonReq)
  of "/dungeon/start":
    result = dungeon_Start(db, jsonReq).toProtoJson
  of "/dungeon/finish":
    result = toProtoJson(dungeon_Finish(db, jsonReq))
  of "/dungeon/battle_start", "/dungeon/battle/start":
    result = dungeon_BattleStart(db, jsonReq, lastBattleInfo)
  of "/dungeon/resume":
    result = dungeon_Resume(db, jsonReq.protoJsonTo(DungeonResumeRequest)).toProtoJson

  of "/event/list_node":
    result = event_ListNode(db)
  of "/event/finish_node":
    result = event_FinishNode(db, jsonReq)

  of "/follow/list":
    result = toProtoJson(follow_List())
  of "/follow/search":
    result = toProtoJson(follow_Search(protoJsonTo(jsonReq, FollowSearchRequest)))
  of "/follow/add":
    result = toProtoJson(follow_Add(protoJsonTo(jsonReq, FollowAddRequest)))
  of "/follow/detail":
    result = toProtoJson(follow_Detail(protoJsonTo(jsonReq, FollowDetailRequest)))

  of "/formation/update":
    result = formation_Update(db, jsonReq)
  of "/formation/switch":
    result = formation_Switch(db, jsonReq)

  of "/gacha/list":
    result = gacha_List(db)
  of "/gacha/execute":
    result = gacha_Execute(db, jsonReq).toProtoJson

  of "/happy_worker/list":
    result = toProtoJson(happy_worker_List(db))
  of "/happy_worker/start":
    result = toProtoJson(happy_worker_Start(db, protoJsonTo(jsonReq, HappyWorkerStartRequest)))
  of "/happy_worker/cancel":
    result = toProtoJson(happy_worker_Cancel(db, protoJsonTo(jsonReq, HappyWorkerCancelRequest)))

  of "/item_request/get":
    result = toProtoJson(item_request_Get())
  of "/item_request/list":
    result = toProtoJson(item_request_List())
  of "/item_request/publish":
    result = toProtoJson(item_request_Publish(protoJsonTo(jsonReq, ItemRequestPublishRequest)))

  of "/mail/list":
    result = toProtoJson(mail_List(db))
  of "/mail/open":
    result = toProtoJson(mail_Open(db, protoJsonTo(jsonReq, MailOpenRequest)))

  of "/mission/receive":
    result = toProtoJson(mission_Receive(db, protoJsonTo(jsonReq, MissionReceiveRequest)))

  of "/news/user_list":
    result = news_UserList()
  of "/news/list":
    result = news_UserList()

  of "/purchase/history":
    result = toProtoJson(purchase_History())

  of "/shop/gem_list":
    result = toProtoJson(shop_GemList())
  of "/shop/random_costume_list":
    result = toProtoJson(shop_RandomCostumeList())
  of "/shop/purchase":
    result = toProtoJson(shop_Purchase(db, protoJsonTo(jsonReq, ShopPurchaseRequest)))

  of "/tension_card/limit_break_enhance":
    result = tensionCard_LimitBreakEnhance(db, protoJsonTo(jsonReq, TensionCardLimitBreakEnhanceRequest)).toProtoJson
  of "/tension_card/lock":
    result = tensionCard_Lock(db, protoJsonTo(jsonReq, TensionCardLockRequest)).toProtoJson
  of "/tension_card/enhance":
    result = tensionCard_Enhance(db, protoJsonTo(jsonReq, TensionCardEnhanceRequest)).toProtoJson

  of "/tip/release":
    result = tip_Release(db, jsonReq)
  of "/tip/release_by_battle":
    result = toProtoJson(tip_ReleaseByBattle(db, protoJsonTo(jsonReq, TipReleaseByBattleRequest)))

  of "/user/cross_date":
    result = user_CrossDate(db, jsonReq)
  of "/user/log_in":
    result = user_LogIn(db).toProtoJson
  
  of "/xb/formation":
    result = xb_Formation(db, jsonReq)
  of "/xb/start":
    result = xb_Start(db, jsonReq)
  of "/xb/update_tension":
    result = xb_UpdateTension(db, jsonReq)
  of "/xb/play":
    result = xb_Play(db, jsonReq)
  of "/user/notification":
    result = user_Notification(db)

  else:
    result = nil