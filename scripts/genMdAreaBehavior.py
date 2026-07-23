from argparse import ArgumentParser
import json

from genMasterData import write_rows


def main():
    parser = ArgumentParser()
    parser.add_argument("area_behavior_json")
    parser.add_argument("out_sql")
    args = parser.parse_args()

    with open(args.area_behavior_json, "r", encoding="utf-8") as f:
        area_behavior_json = json.load(f)

    with open(args.out_sql, "w", encoding="utf-8") as f:
        write_area_behavior_sql(f, area_behavior_json)


def write_area_behavior_sql(f, area_behavior_json):
    def xprint(*args):
        print(*args, file=f)

    xprint("INSERT INTO mdAreaBehavior (actionSequenceId, areaId, conditionId, conditionType, id) VALUES")

    write_rows(xprint, f, [
        (it["action_sequence_id"], it["area_id"], it["condition"]["id"], it["condition"]["type"], it["id"])               
        for it in area_behavior_json
    ])

    xprint(";")
    

if __name__ == "__main__":
    main()
