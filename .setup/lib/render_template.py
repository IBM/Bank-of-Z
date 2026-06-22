#!/usr/bin/env python3

"""
Jinja + YAML Template Rendering Engine (with CLI overrides)

This script renders a Jinja2 template using a YAML configuration file,
with support for:

- YAML-based configuration loading
- Recursive Jinja evaluation inside YAML values
- Environment variable expansion (${VAR})
- Command-line overrides via --extraVar NAME=value
- Strict Jinja mode (StrictUndefined) to fail on missing variables
- Configurable output encoding (default: cp1047, z/OS-friendly)

Processing order:
1. Load YAML configuration file
2. Merge CLI extra variables (--extraVar)
3. Resolve YAML Jinja expressions recursively
4. Merge again into final variable set
5. Render Jinja template
6. Expand environment variables (${VAR}) in rendered output
7. Write output file using specified encoding

Example usage:
    python script.py \
        --configFile config.yaml \
        --templateFile template.j2 \
        --outputFile output.txt \
        --extraVar jobname=DB2DROP

Notes:
- Missing variables in templates will raise errors (strict mode)
- Environment variables are expanded using ${VAR} syntax
- Undefined environment variables are replaced with empty string
"""

import argparse
import os
import re
from copy import deepcopy

import yaml
from jinja2 import Environment, FileSystemLoader, StrictUndefined


def expand_env_vars(value):
    pattern = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")

    if not isinstance(value, str):
        return value

    def repl(match):
        return os.environ.get(match.group(1), "")

    return pattern.sub(repl, value)


def render_config(config):
    """
    Recursively resolve Jinja expressions inside YAML.
    """
    result = deepcopy(config)

    env = Environment(undefined=StrictUndefined)

    for _ in range(20):
        changed = False

        def resolve(node):
            nonlocal changed

            if isinstance(node, dict):
                return {k: resolve(v) for k, v in node.items()}

            if isinstance(node, list):
                return [resolve(v) for v in node]

            if isinstance(node, str):
                rendered = node

                if "{{" in rendered:
                    rendered = env.from_string(rendered).render(**result)

                rendered = expand_env_vars(rendered)

                if rendered != node:
                    changed = True

                return rendered

            return node

        result = resolve(result)

        if not changed:
            break

    return result


def parse_extra_vars(values):
    extra_vars = {}

    for item in values:
        if "=" not in item:
            raise ValueError(f"Invalid --extraVar '{item}', expected NAME=value")

        name, value = item.split("=", 1)
        extra_vars[name] = value

    return extra_vars


def load_config(filename):
    with open(filename, "r", encoding="utf-8") as fd:
        config = yaml.safe_load(fd)

    return render_config(config)


def render_template(template_file, variables):
    template_dir = os.path.dirname(os.path.abspath(template_file))
    template_name = os.path.basename(template_file)

    env = Environment(
        loader=FileSystemLoader(template_dir),
        autoescape=False,
        undefined=StrictUndefined,
    )

    template = env.get_template(template_name)
    return template.render(**variables)


def main():
    parser = argparse.ArgumentParser(
        description="Render a Jinja template using a YAML configuration file."
    )

    parser.add_argument("--configFile", required=True)
    parser.add_argument("--templateFile", required=True)
    parser.add_argument("--outputFile", required=True)

    parser.add_argument(
        "--extraVar",
        action="append",
        default=[],
        help="NAME=value"
    )

    parser.add_argument(
        "--outputEncoding",
        default="cp1047",
        help="Output file encoding (default: cp1047)"
    )

    args = parser.parse_args()

    extra_vars = parse_extra_vars(args.extraVar)

    with open(args.configFile, "r", encoding="utf-8") as fd:
        config = yaml.safe_load(fd)

    config.update(extra_vars)

    config = render_config(config)

    variables = {}
    variables.update(config)
    variables.update(extra_vars)

    rendered = render_template(args.templateFile, variables)

    rendered = expand_env_vars(rendered)

    with open(args.outputFile, "w", encoding=args.outputEncoding) as fd:
        fd.write(rendered)


if __name__ == "__main__":
    main()
