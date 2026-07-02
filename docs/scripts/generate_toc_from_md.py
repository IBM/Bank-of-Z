#!/usr/bin/env python3
"""
Generate TOC from Markdown files in docs/ folder
This script scans MD files directly 
"""

import os
import re
from pathlib import Path
import yaml

# Mapping of folder names to readable section names
SECTION_MAPPING = {
    "introduction': 'Introduction",
    "architecture": "Architecture",
    "installation-and-setup": "Installation and Setup",
    "tutorials": "Tutorials",
    "development-workflows": "Development Workflows",
    "reference": "Reference",
    "troubleshooting": "Troubleshooting",
    "release-information": "Release Information"
}

def get_title(md_file):
    """Extract title from front matter or first H1 heading."""
    try:
        content = md_file.read_text(encoding="utf-8")
            fm = re.search(
            r"^---\s*\n.*?title:\s*(.+?)\s*\n",
            content,
            re.MULTILINE | re.DOTALL,
            )
            if fm:
                return fm.group(1).strip().strip('"').strip("'")
            h1 = re.search(r"^#\s+(.+)$", content, re.MULTILINE)
            if h1:
                return h1.group(1).strip()
            except Exception as e:
            print(f"Warning reading {md_file}: {e}")
            return md_file.stem.replace("-", " ").title()

def generate_toc():
    docs_dir = Path("docs")
    if not docs_dir.exists():
    print("ERROR: docs folder not found")
    return

  toc = [
        {
            "title": "Home",
            "url": "/"
        }
    ]  
    for section in sorted(docs_dir.iterdir()):

        if not section.is_dir():
            continue

        section_slug = section.name

        section_title = SECTION_MAPPING.get(
            section_slug,
            section_slug.replace("-", " ").title()
        )
        section_entry = {
            "title": section_title,
            "url": f"/docs/{section_slug}/",
            "children": []
        }
        md_files = sorted(section.glob("*.md"))

        for md_file in md_files:

            if md_file.name == "index.md":
                continue

            title = get_title(md_file)

            section_entry["children"].append(
                {
                    "title": title,
                    "url": f"/docs/{section_slug}/{md_file.stem}.html"
                }
            )

            print(
                f"Added: {section_title} -> {title}"
            )
         toc.append(section_entry)

    output = Path("_data/toc.yml")
    output.parent.mkdir(exist_ok=True)

    with open(output, "w", encoding="utf-8") as f:

        f.write(
            "# Auto-generated TOC\n"
            "# Do not edit manually\n\n"
        )

        yaml.dump(
            toc,
            f,
            sort_keys=False,
            default_flow_style=False,
            allow_unicode=True,
        )

    print()
    print(f"Generated: {output}")   
# Made with Bob
