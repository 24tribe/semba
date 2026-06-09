from argparse import ArgumentParser
import re
import subprocess
import sys

VERSION_REGEX = re.compile(r"Nim Compiler Version (\d+)\.(\d+)\.(\d+)")
TARGET_REGEX = re.compile(r"(\d+)\.(\d+)\.(\d+)")


def main():
    parser = ArgumentParser()
    parser.add_argument("target_version")
    args = parser.parse_args()

    output = subprocess.check_output(['nim', '-v']).decode("utf-8")

    match = VERSION_REGEX.search(output)
    assert match
    major, minor, patch = groups_to_version(match.groups())

    t_match = TARGET_REGEX.search(args.target_version)
    assert t_match
    t_major, t_minor, t_patch = groups_to_version(t_match.groups())

    if major >= t_major and minor >= t_minor and patch >= t_patch:
        status_code = 0
    else:
        status_code = 1

    sys.exit(status_code)


def groups_to_version(groups):
    return tuple(map(int, groups))


if __name__ == "__main__":
    main()