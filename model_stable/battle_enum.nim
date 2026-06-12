type BattleResult* {.pure.} = enum
  won, lost, retire

type BattleWonResultType* {.pure.} = enum
  on_adventure, on_battle

type BattleAdvantageType* {.pure.} = enum
  normal, advantage, disadvantage