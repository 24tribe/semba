from argparse import ArgumentParser
import json

from genMasterData import write_rows

def main():
    parser = ArgumentParser()
    parser.add_argument("dungeon_area_item_json")
    parser.add_argument("out_sql")
    args = parser.parse_args()

    with open(args.dungeon_area_item_json, "r", encoding="utf-8") as f:
        dungeon_area_item = json.load(f)

    with open(args.out_sql, "w", encoding="utf-8") as f:
        gen_md_dungeon_area_item(dungeon_area_item, f)

    print("OK")


def gen_md_dungeon_area_item(dungeon_area_item, f):
    xprint = lambda *args: print(*args, file=f)

    xprint("INSERT INTO mdDungeonAreaItem (id, areaItemRewardIds, areaItemBaseId) VALUES")

    write_rows(xprint, f, [
        (dai["id"], dai["area_item_reward_ids"], dai["area_item_base_id"]) for dai in dungeon_area_item
    ])

    xprint(";")


if __name__ == "__main__":
    main()