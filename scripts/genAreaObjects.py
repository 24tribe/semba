from argparse import ArgumentParser
import json
import sys


def main():
    parser = ArgumentParser()
    parser.add_argument("online_logs_json")
    parser.add_argument("output_sql")
    args = parser.parse_args()

    with open(args.online_logs_json, "r", encoding="utf-8") as f:
        debug_logs = json.load(f)

    area_ids = set()

    adventure_area_object_flows = filter(lambda x: x["uri"] == "/adventure/area_object", debug_logs)

    first_adventure_area_object_flows = []

    for flow in adventure_area_object_flows:
        area_id = flow["req"]["areaId"]
        if area_id not in area_ids:
            first_adventure_area_object_flows.append(flow)
            area_ids.add(area_id)

    with open(args.output_sql, "w", encoding="utf-8") as f:
        rows = []
        for flow in first_adventure_area_object_flows:
            if flow["res"] is not None: # why areaId=800010 res is empty?
                areaId = flow["req"]["areaId"]
                write_sql(f, flow["res"], areaId)
                rows += prepare_dummy_area_objects(areaId, flow["res"]["areaObjects"])
        
        write_area_objects_without_id(f, rows)


def write_sql(f, data, area_id):
    print(f"-- Area {area_id}", file=f)
    # enemies
    enemies = list(filter(lambda obj: "areaEnemyRateSetId" in obj, data["areaObjects"]))

    if enemies:
        write_enemies(f, enemies, area_id)

    write_area_objects_sql(f, data, area_id)

    if "areaItems" in data:
        write_area_items(f, data, area_id)


def write_area_objects_sql(f, data, area_id):
    area_objects = list(filter(lambda obj: "areaObjectId" in obj, data["areaObjects"]))

    if len(area_objects) == 0:
        return

    # interactive? objects
    print("INSERT INTO areaObjects (areaId, areaObjectId, areaPointId, areaObjectBehaviorId, action)", file=f)
    print("VALUES", file=f)
    first = True
    for obj in area_objects:
        if first:
            first = False
        else:
            f.write(",")

        if "action" in obj:
            action = json.dumps(obj["action"]).replace("'", "''")
            action = f"'{action}'"
        else:
            action = "''"

        print(f"({area_id}, {obj["areaObjectId"]}, {obj["areaPointId"]}, {obj["areaObjectBehaviorId"]}, {action})", file=f)

    print(";", file=f)


def write_enemies(f, enemies, area_id):
    print("INSERT INTO areaEnemies (areaId, areaPointId, areaEnemyRateSetId, action)", file=f)
    print("VALUES", file=f)
    first = True
    for obj in enemies:
        if first:
            first = False
        else:
            f.write(",")

        print(f"({area_id}, {obj["areaPointId"]}, {obj["areaEnemyRateSetId"]}, '{json.dumps(obj["action"])}')", file=f)

    print(";", file=f)


def write_area_items(f, data, area_id):
    # area items
    print("INSERT INTO areaItems (areaId, areaItemId)", file=f)
    print("VALUES", file=f)

    first = True
    for obj in data["areaItems"]:
        if first:
            first = False
        else:
            f.write(",")

        print(f"({area_id}, {obj["areaItemId"]})", file=f)
    print(";", file=f)


def prepare_dummy_area_objects(area_id, area_objects):
    targets = filter(lambda x: "areaObjectId" not in x and "areaEnemyRateSetId" not in x, area_objects)
    targets = list(targets)

    return [
        (area_id, target["areaPointId"], target["areaObjectBehaviorId"], json.dumps(target["action"]))
        for target in targets
    ]


def write_area_objects_without_id(f, rows):
    xprint = lambda *args: print(*args, file=f)

    xprint("INSERT INTO dummyAreaObjects (areaId, areaPointId, areaObjectBehaviorId, action) VALUES")

    first = True

    for areaId, areaPointId, areaObjectBehaviorId, action in rows:
        if first:
            first = False
        else:
            f.write(",")

        xprint(f"({areaId}, {areaPointId}, {areaObjectBehaviorId}, '{action}')")

    xprint(";")


if __name__ == "__main__":
    main()