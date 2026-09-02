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
        config = yaml.safe_load(fd)
    return normalize_config(config)


def normalize_config(config):
    """Support the legacy ``global`` section during the cfg migration."""
    if not isinstance(config, dict):
        return config

    result = deepcopy(config)
    if "cfg" not in result and isinstance(result.get("global"), dict):
        result["cfg"] = deepcopy(result["global"])

    def replace_legacy_reference(node):
        if isinstance(node, dict):
            return {key: replace_legacy_reference(value) for key, value in node.items()}
        if isinstance(node, list):
            return [replace_legacy_reference(value) for value in node]
        if isinstance(node, str):
            return node.replace("global.", "cfg.")
        return node

    return replace_legacy_reference(result)


def expand_env_vars_deep(node):
    """Recursively expand ${VAR} env references in all string values."""
    if isinstance(node, dict):
        return {k: expand_env_vars_deep(v) for k, v in node.items()}
    if isinstance(node, list):
        return [expand_env_vars_deep(v) for v in node]
    if isinstance(node, str):
        return expand_env_vars(node)
    return node


def render_config(data):
    def expand_tree(node):
        if isinstance(node, dict):
            return {key: expand_tree(value) for key, value in node.items()}
        if isinstance(node, list):
            return [expand_tree(value) for value in node]
        return expand_env_vars(node)

    # Expand environment variables before resolving Jinja. Otherwise a
    # construct such as {{ cfg.zos_admin_user | lower }} receives ${USER},
    # lowers it to ${user}, and loses the value on case-sensitive systems.
    result = expand_tree(deepcopy(data))
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
                    # Expand env vars in the context first so filters like
                    # | lower operate on resolved values (e.g. IBMUSER not ${USER})
                    context = expand_env_vars_deep(result)
                    rendered = Template(rendered).render(**context)
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
