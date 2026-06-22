#!/usr/bin/env python3

"""
YAML Configuration Resolver & Value Extractor

This script loads a YAML configuration file defined by the CONFIG_FILE
environment variable, performs recursive resolution of:

- Jinja2-style expressions: {{ variable }}
- Environment variables: ${VAR}

It then allows retrieving a specific value using:
    <section> <key>

Features:
- Recursive resolution (multi-pass up to 20 iterations)
- Deep YAML structure support (dicts, lists, strings)
- Safe handling of missing values (returns empty string)
- Environment variable expansion

Usage:
    CONFIG_FILE=config.yaml python script.py <section> <key>

Example:
    CONFIG_FILE=config.yaml python script.py database host
"""

import os
import re
import sys
from copy import deepcopy

import yaml
from jinja2 import Template

ENV_PATTERN = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")


def expand_env_vars(value):
    if not isinstance(value, str):
        return value

    def repl(match):
        return os.environ.get(match.group(1), "")

    return ENV_PATTERN.sub(repl, value)


def load_config(config_file):
    with open(config_file, "r", encoding="utf-8") as fd:
        return yaml.safe_load(fd)


def render_config(data):
    result = deepcopy(data)
    for _ in range(20):
        changed = False

        def render_node(node):
            nonlocal changed
            if isinstance(node, dict):
                return {k: render_node(v) for k, v in node.items()}
            if isinstance(node, list):
                return [render_node(v) for v in node]
            if isinstance(node, str):
                rendered = node
                if "{{" in rendered:
                    rendered = Template(rendered).render(**result)
                rendered = expand_env_vars(rendered)
                if rendered != node:
                    changed = True
                return rendered
            return node

        result = render_node(result)
        if not changed:
            break
    return result


def get_value(config, section, key):
    section_data = config.get(section)
    if not isinstance(section_data, dict):
        return ""
    value = section_data.get(key, "")
    if value is None:
        return ""
    return value


def main():
    config_file = os.environ.get("CONFIG_FILE")
    if not config_file:
        print("CONFIG_FILE environment variable is not defined", file=sys.stderr)
        sys.exit(1)
    if len(sys.argv) != 3:
        print(
            f"Usage: {sys.argv[0]} <section> <key>",
            file=sys.stderr,
        )
        sys.exit(1)
    section = sys.argv[1]
    key = sys.argv[2]
    config = load_config(config_file)
    config = render_config(config)
    value = get_value(config, section, key)
    print(value)


if __name__ == "__main__":
    main()
