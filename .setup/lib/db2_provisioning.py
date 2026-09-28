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
    name = ssid.upper() + "MSTR"
    absent = False
    for line in text.upper().splitlines():
        if re.search(r"\bD\s+A\s*,", line):
            continue
        fields = line.split()
        if name not in fields:
            continue
        if "NOT FOUND" in line:
            absent = True
        elif "STC" in fields:
            return "active"
    return "inactive" if absent else "unknown"


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
    render = commands.add_parser("render")
    render.add_argument("template", type=Path)
    render.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.command == "status":
        print(master_status(sys.stdin.read(), args.ssid))
    else:
        data = prepare(args.template.read_text(encoding="utf-8"), os.environ)
        args.output.write_text(yaml.safe_dump(data, sort_keys=False), encoding="utf-8")


if __name__ == "__main__":
    main()
