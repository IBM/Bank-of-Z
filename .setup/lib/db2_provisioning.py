"""Prepare zconfig input and classify Db2 master address-space responses."""

import argparse
import os
import re
import sys
from pathlib import Path

import yaml
from jinja2 import Environment, StrictUndefined


def master_status(text, ssid):
    """Return active, inactive, or unknown; command echoes are not evidence."""
    return task_status(text, ssid.upper() + "MSTR")


def task_status(text, name):
    """Classify an exact address-space name without trusting command echoes."""
    name = name.upper()
    absent = False
    for line in text.upper().splitlines():
        if re.search(r"\bD\s+A\s*,", line):
            continue
        fields = line.split()
        if name not in fields:
            continue
        if "NOT FOUND" in line:
            absent = True
        elif "STC" in fields or re.search(r"\bA=[0-9A-F]{4}\b", line):
            return "active"
    return "inactive" if absent else "unknown"


def managed_state(text, ssid):
    """Match a complete subsystem URI, including in zconfig's table output."""
    target = re.escape("db2://" + ssid)
    pattern = r"(?<![\w:/])" + target + r"(?![\w$#@./:-])"
    return "present" if re.search(pattern, text) else "absent"


def validate_bank_config(config, environ):
    """Keep shell-selected Db2 identity consistent with the Bank SQL input."""
    settings = config["db2"]
    provision = str(config.get("cfg", config.get("global", {})).get("db2_provision", "false")).lower()
    if provision not in ("true", "false"):
        raise ValueError("db2_provision must be true or false")
    expected = {
        "DB2_SSID": settings["ssid"],
        "DB2_HLQ": settings["db2_hlq"],
        "DB2_JAVA_FOLDER": settings["db2_java_dir"],
        "DB2_PROVISION": provision,
    }
    for name, value in expected.items():
        actual = environ.get(name, str(value))
        if name == "DB2_PROVISION":
            actual = actual.lower()
        if actual != str(value):
            raise ValueError(
                f"{name} disagrees with CONFIG_FILE. Set Db2 identity in "
                "BOZ_CONFIG_FILE; conflicting shell overrides are not supported for Db2 lifecycle or Bank installation."
            )


def wlm_status(text, name):
    """Read only an unambiguous row for the requested WLM environment."""
    states = set()
    for line in text.upper().splitlines():
        fields = line.split()
        if len(fields) >= 2 and fields[0] == name.upper():
            states.add(fields[1])
    return states.pop() if len(states) == 1 else "unknown"


def prepare(template, environ):
    """Resolve the existing template using exported setup values, without eval."""
    names = {
        "db2_ssid": "DB2_SSID", "db2_hlq": "DB2_HLQ",
        "cics_hlq": "CICS_HLQ",
    }
    for suffix in (
        "user_catalog", "authid", "volume", "storage_class", "data_class",
        "java_home", "javaenv", "javaenvv", "jvmprops", "sdsnexit",
    ):
        names["db2_" + suffix] = "DB2_PROVISION_" + suffix.upper()
    values = {key: environ[value] for key, value in names.items()}
    optional = {"db2_volume", "db2_storage_class", "db2_data_class"}
    for key, value in values.items():
        if key not in optional and not value.strip():
            raise ValueError("Missing provisioning value: " + names[key])
    if not re.fullmatch(r"[A-Z$#@][A-Z0-9$#@]{0,3}", values["db2_ssid"]):
        raise ValueError("Invalid Db2 subsystem ID")
    renderer = Environment(undefined=StrictUndefined)

    def resolve(node):
        if isinstance(node, dict):
            return {key: resolve(value) for key, value in node.items()}
        if isinstance(node, list):
            return [resolve(value) for value in node]
        if isinstance(node, str):
            return renderer.from_string(node).render(vars=values)
        return node

    result = resolve(yaml.safe_load(template))
    settings = result["db2"]
    storage = settings.get("volumes_and_sms_classes", {})
    settings["volumes_and_sms_classes"] = {
        key: value for key, value in storage.items() if str(value).strip()
    }
    if not settings["volumes_and_sms_classes"]:
        del settings["volumes_and_sms_classes"]
    catalog = environ.get("DB2_PROVISION_CATALOG", "").strip()
    if catalog:
        settings["catalog"] = catalog
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    status = commands.add_parser("status")
    status.add_argument("ssid")
    task = commands.add_parser("task-status")
    task.add_argument("name")
    managed = commands.add_parser("managed-state")
    managed.add_argument("ssid")
    check = commands.add_parser("check-config")
    check.add_argument("config", type=Path)
    check.add_argument("--provision", action="store_true")
    wlm = commands.add_parser("wlm-status")
    wlm.add_argument("name")
    render = commands.add_parser("render")
    render.add_argument("template", type=Path)
    render.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.command == "status":
        print(master_status(sys.stdin.read(), args.ssid))
    elif args.command == "task-status":
        print(task_status(sys.stdin.read(), args.name))
    elif args.command == "managed-state":
        print(managed_state(sys.stdin.read(), args.ssid))
    elif args.command == "check-config":
        from config import load_config, render_config

        try:
            validate_bank_config(render_config(load_config(args.config)), os.environ)
            if args.provision:
                template = Path(__file__).resolve().parents[1] / "zconfig/db2-provision.yaml"
                prepare(template.read_text(encoding="utf-8"), os.environ)
        except (KeyError, ValueError) as error:
            parser.exit(1, str(error) + "\n")
    elif args.command == "wlm-status":
        print(wlm_status(sys.stdin.read(), args.name))
    elif args.command == "render":
        data = prepare(args.template.read_text(encoding="utf-8"), os.environ)
        args.output.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")


if __name__ == "__main__":
    main()
