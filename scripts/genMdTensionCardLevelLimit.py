from argparse import ArgumentParser
import json

from genMasterData import write_rows


def main():
    parser = ArgumentParser()
    parser.add_argument("tension_card_level_limit_json")
    parser.add_argument("out_sql")
    args = parser.parse_args()

    with open(args.tension_card_level_limit_json, "r", encoding="utf-8") as f:
        tension_card_level_limit_json = json.load(f)

    with open(args.out_sql, "w", encoding="utf-8") as f:
        write_tension_card_level_limit_sql(f, tension_card_level_limit_json)


def write_tension_card_level_limit_sql(f, tension_card_level_limit_json):
    def xprint(*args):
        print(*args, file=f)

    xprint("INSERT INTO mdTensionCardLevelLimit (id, tensionCardId, goldCost, maxLevel, itemCosts)")

    write_rows(xprint, f, [
        (it["id"], it["tension_card_id"], it["gold_cost"], it["max_level"], it["item_costs"])               
        for it in tension_card_level_limit_json
    ])

    xprint(";")
    

if __name__ == "__main__":
    main()
