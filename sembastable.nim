import std/json
import std/options

import db_connector/db_sqlite

import api_stable/adventure
import api_stable/battle
import api_stable/character
import api_stable/dungeon
import api_stable/event
import api_stable/follow
import api_stable/formation
import api_stable/gacha
import api_stable/happy_worker
import api_stable/item_request
import api_stable/mail
import api_stable/mission
import api_stable/news
import api_stable/purchase
import api_stable/shop
import api_stable/tension_card
import api_stable/tip
import api_stable/user
import api_stable/xb
import model_stable/battle
import protojson


proc getJsonResultStable*(
  uri: string, jsonReq: JsonNode,
  db: DbConn, lastBattleInfo: var Option[BattleInfo]
): JsonNode =
  if uri == "/adventure/area_object":
    result = adventure_AreaObject(db, jsonReq)
  elif uri == "/adventure/find_graffiti":
    result = %*adventure_FindGraffiti(db, to(jsonReq, AdventureFindGraffitiRequest))
  elif uri == "/adventure/move_to_area":
    result = %*adventure_MoveToArea(db, to(jsonReq, AdventureMoveToAreaRequest))
  elif uri == "/adventure/update_character_status":
    result = adventure_UpdateCharacterStatus(db, jsonReq)
  elif uri == "/adventure/read_sequence":
    result = adventure_ReadSequence(db, to(jsonReq, AdventureReadSequenceRequest))
  elif uri == "/adventure/acquire_area_item":
    result = adventure_AcquireAreaItem(db, to(jsonReq, AdventureAcquireAreaItemRequest))
  elif uri == "/adventure/release_event_lift":
    result = adventure_ReleaseEventLift(jsonReq)
  elif uri == "/adventure/warp_area_locator":
    result = adventure_WarpAreaLocator(db, jsonReq)
  elif uri == "/adventure/hospital":
    result = adventure_Hospital(db)
  elif uri == "/adventure/access_warp_point":
    result = %*adventure_AccessWarpPoint(db, jsonReq)

  elif uri == "/auth/steam_user":
    result = %*{"userId": 696969696969}
  elif uri == "/auth/nonce":
    result = %*{"nonce": "6969696969696969"}
  elif uri == "/auth/sign_in":
    result = %*{"sessionToken": "69696969-6969-6969-6969-696969696969", "language": 2}

  elif uri == "/battle/start":
    result = battle_Start(db, lastBattleInfo, jsonReq)
  elif uri == "/battle/finish":
    result = battle_Finish(db, lastBattleInfo, jsonReq)
  elif uri == "/battle/restart":
    result = %*battle_Restart(db, lastBattleInfo, to(jsonReq, BattleRestartRequest))

  elif uri == "/character/costume_update":
    result = character_CostumeUpdate(db, jsonReq)
  elif uri == "/character/limit_break":
    result = character_LimitBreak(db, jsonReq)
  elif uri == "/character/equip":
    result = %*character_Equip(db, to(jsonReq, CharacterEquipRequest))
  elif uri == "/character/enhance":
    result = %*character_Enhance(db, to(jsonReq, CharacterEnhanceRequest))

  elif uri == "/dungeon/entry":
    result = dungeon_Entry(db, jsonReq)
  elif uri == "/dungeon/start":
    result = dungeon_Start(db, jsonReq)
  elif uri == "/dungeon/finish":
    result = dungeon_Finish(db, jsonReq)
  elif uri == "/dungeon/battle_start" or uri == "/dungeon/battle/start":
    result = dungeon_BattleStart(db, jsonReq, lastBattleInfo)
  elif uri == "/dungeon/resume":
    result = dungeon_Resume(db, jsonReq)

  elif uri == "/event/list_node":
    result = event_ListNode(db)
  elif uri == "/event/finish_node":
    result = event_FinishNode(db, jsonReq)

  elif uri == "/follow/list":
    result = %*follow_List()
  elif uri == "/follow/search":
    result = toJson(follow_Search(protoJsonTo(jsonReq, FollowSearchRequest)))
  elif uri == "/follow/add":
    result = %*follow_Add(to(jsonReq, FollowAddRequest))
  elif uri == "/follow/detail":
    result = %*follow_Detail(to(jsonReq, FollowDetailRequest))

  elif uri == "/formation/update":
    result = formation_Update(db, jsonReq)
  elif uri == "/formation/switch":
    result = formation_Switch(db, jsonReq)

  elif uri == "/gacha/list":
    result = gacha_List(db)
  elif uri == "/gacha/execute":
    result = gacha_Execute(db, jsonReq)

  elif uri == "/happy_worker/list":
    result = %*happy_worker_List(db)
  elif uri == "/happy_worker/start":
    result = %*happy_worker_Start(db, to(jsonReq, HappyWorkerStartRequest))
  elif uri == "/happy_worker/cancel":
    result = %*happy_worker_Cancel(db, to(jsonReq, HappyWorkerCancelRequest))

  elif uri == "/item_request/get":
    result = toJson(item_request_Get())
  elif uri == "/item_request/list":
    result = toJson(item_request_List())
  elif uri == "/item_request/publish":
    result = toJson(item_request_Publish(protoJsonTo(jsonReq, ItemRequestPublishRequest)))

  elif uri == "/mail/list":
    result = %*mail_List(db)
  elif uri == "/mail/open":
    result = %*mail_Open(db, to(jsonReq, MailOpenRequest))

  elif uri == "/mission/receive":
    result = %*mission_Receive(db, to(jsonReq, MissionReceiveRequest))

  elif uri == "/news/user_list":
    result = news_UserList()
  elif uri == "/news/list":
    result = news_UserList()

  elif uri == "/purchase/history":
    result = %*purchase_History()

  elif uri == "/shop/gem_list":
    result = %*shop_GemList()
  elif uri == "/shop/random_costume_list":
    result = %*shop_RandomCostumeList()
  elif uri == "/shop/purchase":
    result = %*shop_Purchase(db, to(jsonReq, ShopPurchaseRequest))

  elif uri == "/tension_card/limit_break_enhance":
    result = tensionCard_LimitBreakEnhance(db, jsonReq)
  elif uri == "/tension_card/lock":
    result = tensionCard_Lock(db, jsonReq)

  elif uri == "/tip/release":
    result = tip_Release(db, jsonReq)
  elif uri == "/tip/release_by_battle":
    result = %*tip_ReleaseByBattle(db, to(jsonReq, TipReleaseByBattleRequest))

  elif uri == "/user/cross_date":
    result = user_CrossDate(db, jsonReq)
  elif uri == "/user/log_in":
    result = user_LogIn(db)
  
  elif uri == "/xb/formation":
    result = xb_Formation(db, jsonReq)
  elif uri == "/xb/start":
    result = xb_Start(db, jsonReq)
  elif uri == "/xb/update_tension":
    result = xb_UpdateTension(db, jsonReq)
  elif uri == "/xb/play":
    result = xb_Play(db, jsonReq)
  elif uri == "/user/notification":
    result = user_Notification(db)

  else:
    result = nil