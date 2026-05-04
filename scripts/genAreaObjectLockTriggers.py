from argparse import ArgumentParser
from pathlib import Path
from enum import Enum
import json

from genMasterData import write_rows

class AreaObjectLockTrigger(Enum):
  BATTLE = 1
  MINIGAME = 2

MANUAL_IDS = [
  (10518102, (AreaObjectLockTrigger.BATTLE, 10828701)),
  (10518002, (AreaObjectLockTrigger.BATTLE, 10828601)),
  (10511402, (AreaObjectLockTrigger.BATTLE, 10828101)),
  (10510802, (AreaObjectLockTrigger.BATTLE, 10829401)),
  (10512102, (AreaObjectLockTrigger.BATTLE, 10828201)),
  (10501302, (AreaObjectLockTrigger.BATTLE, 10829001)),
  (10510502, (AreaObjectLockTrigger.BATTLE, 10829401)),
  (10501802, (AreaObjectLockTrigger.BATTLE, 10829801)),
  (10502502, (AreaObjectLockTrigger.BATTLE, 10830101)),
  (10502802, (AreaObjectLockTrigger.BATTLE, 10830501)),
  (10503102, (AreaObjectLockTrigger.BATTLE, 10830301)),
  (10504102, (AreaObjectLockTrigger.BATTLE, 10826701)),
  (10519202, (AreaObjectLockTrigger.BATTLE, 10832301)),
  (10504502, (AreaObjectLockTrigger.MINIGAME, 105016)),
  (10512402, (AreaObjectLockTrigger.BATTLE, 10825301)),
  (10517302, (AreaObjectLockTrigger.BATTLE, 10827301)),
  (10506002, (AreaObjectLockTrigger.MINIGAME, 105012)),
  (10505202, (AreaObjectLockTrigger.BATTLE, 10827701)),
  (10513402, (AreaObjectLockTrigger.BATTLE, 10831401)),
  (10514102, (AreaObjectLockTrigger.BATTLE, 10831801)),
  (13512202, (AreaObjectLockTrigger.BATTLE, 13512301)),
  (13524902, (AreaObjectLockTrigger.BATTLE, 13813201)),
  (13524602, (AreaObjectLockTrigger.BATTLE, 13813001)),
  (13524502, (AreaObjectLockTrigger.BATTLE, 13812801)),
  (13524302, (AreaObjectLockTrigger.MINIGAME, 102060)),
  (13524402, (AreaObjectLockTrigger.BATTLE, 13812501)),
  (13526002, (AreaObjectLockTrigger.BATTLE, 13814601)),
  (13525402, (AreaObjectLockTrigger.BATTLE, 13814101)),
  (13502602, (AreaObjectLockTrigger.BATTLE, 13813801)),
  (13518502, (AreaObjectLockTrigger.BATTLE, 13804801)),
  (13505802, (AreaObjectLockTrigger.BATTLE, 13809901)),
  (13522302, (AreaObjectLockTrigger.BATTLE, 13810201)),
  (13522702, (AreaObjectLockTrigger.BATTLE, 13810501)),
  (13523202, (AreaObjectLockTrigger.BATTLE, 13810901)),
  (13520402, (AreaObjectLockTrigger.BATTLE, 13806101)),
  (13520502, (AreaObjectLockTrigger.BATTLE, 13806201)),
  (13521302, (AreaObjectLockTrigger.BATTLE, 13806301)),
  (13522002, (AreaObjectLockTrigger.BATTLE, 13806501)),
  (13519002, (AreaObjectLockTrigger.BATTLE, 13805401)),
  (13519402, (AreaObjectLockTrigger.BATTLE, 13805701)),
  (10503902, (AreaObjectLockTrigger.BATTLE, 10826401)),
]

def check_for_duplicates(area_object_locks):
  ids = set(aol[0] for aol in area_object_locks)

  assert len(ids) == len(area_object_locks)


def get_area_object_locks_from_online_logs(online_logs):
  all_area_object_locks = MANUAL_IDS[:]
  last_battle_start = None

  for online_log in online_logs:
    if online_log["uri"] == "/battle/start":
      last_battle_start = online_log
    elif online_log["uri"] == "/battle/finish":
      area_object_locks = online_log["res"]["changedResources"].get("areaObjectLocks", [])
      if area_object_locks:
        assert len(area_object_locks) == 1
        assert last_battle_start
        battle_triggers = list(
          filter(lambda bt: bt.get("triggerType", "area_enemy") == "area_object", last_battle_start["req"]["battleTriggers"])
        )

        assert len(battle_triggers) == 1
        trigger_ids = battle_triggers[0]["triggerIds"]

        if len(trigger_ids) != 1:
          # can't know which one is the trigger
          continue

        assert battle_triggers[0]["triggerType"] == "area_object"
        data = (area_object_locks[0]["areaObjectLockId"], (AreaObjectLockTrigger.BATTLE, trigger_ids[0]))
        all_area_object_locks.append(data)
        last_battle_start = None
    elif online_log["uri"] == "/adventure/read_sequence":
      area_object_locks = online_log["res"]["changedResources"].get("areaObjectLocks", [])
      if area_object_locks:
        assert len(area_object_locks) == 1
        miniGameId = online_log["req"].get("miniGameId", None)
        assert miniGameId is not None
        data = (area_object_locks[0]["areaObjectLockId"], (AreaObjectLockTrigger.MINIGAME, miniGameId))
        all_area_object_locks.append(data)

  check_for_duplicates(all_area_object_locks)
  return dict(all_area_object_locks)


def write_area_object_lock_triggers_sql(area_object_locks, md_area_object_lock_ids, f):
  xprint = lambda *args: print(*args, file=f)

  xprint("INSERT INTO areaObjectLockTriggers (areaObjectLockId, triggerType, triggerId) VALUES")

  write_rows(xprint, f, [
    (aoli, area_object_locks[aoli][0], area_object_locks[aoli][1]) for aoli in md_area_object_lock_ids
  ])

  xprint(";")


def main():
  parser = ArgumentParser()
  parser.add_argument("online_logs_json")
  parser.add_argument("master_data_dir", type=Path)
  parser.add_argument("out_sql")
  args = parser.parse_args()

  with open(args.online_logs_json, "r", encoding="utf-8") as f:
    online_logs = json.load(f)

  with open(args.master_data_dir/"area_object_lock.json", "r", encoding="utf-8") as f:
    md_area_object_lock_ids = set(aol["id"] for aol in json.load(f))

  all_area_object_locks = get_area_object_locks_from_online_logs(online_logs)

  with open(args.out_sql, "w", encoding="utf-8") as f:
    write_area_object_lock_triggers_sql(all_area_object_locks, md_area_object_lock_ids, f)

  print("OK")


if __name__ == "__main__":
  main()