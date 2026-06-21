type BattleResult* {.pure.} = enum
  won, lost, retire

type BattleWonResultType* {.pure.} = enum
  on_adventure, on_battle

type BattleAdvantageType* {.pure.} = enum
  normal, advantage, disadvantage

type BattleTaskTopicType* {.pure.} = enum
  attach_pressure, attach_unfortified,
  shark_eat_mine, heal_hp, brave_diver_break_leg,
  special_attack, qte, attach_scared, attach_electric, hit_back_to_eyeball

type BattleTriggerType* {.pure.} = enum
  area_enemy, area_object,
  action_sequence, field_boss, dungeon, fractal_vise,
  area_berserk_enemy, trial_battle, ruled_battle, fractal_vise_boss