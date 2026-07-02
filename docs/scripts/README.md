# Documentation Scripts

This directory contains scripts for managing the Bank of Z documentation.

## convert_dita_to_md.py

Converts DITA XML files to Markdown and generates a dynamic Table of Contents.

### Usage

```bash
python3 scripts/convert_dita_to_md.py
```

### What It Does

1. **Scans** the `Docs/` folder for DITA files
2. **Converts** DITA XML to Markdown format
3. **Creates** organized folder structure in `docs/`
4. **Generates** `_data/toc.yml` automatically
5. **Creates** index pages for each section

### Requirements

```bash
pip3 install pyyaml
```

### Output

- Markdown files in `docs/` folder
- Auto-generated `_data/toc.yml`
- Section index pages

### Example

```bash
# Before running
Docs/com.ibm.tutorials.doc/getting-started.dita

# After running
docs/tutorials/getting-started.md
docs/tutorials/index.md
_data/toc.yml (updated)
```

## Adding New Scripts

Place additional documentation management scripts in this directory.

### Naming Convention

- Use descriptive names: `convert_dita_to_md.py`
- Use underscores for spaces: `generate_pdf_docs.py`
- Include `.py` extension for Python scripts

### Documentation

Each script should include:
- Docstring explaining purpose
- Usage instructions
- Requirements/dependencies
- Example output

## See Also

- [DYNAMIC_TOC_GUIDE.md](../DYNAMIC_TOC_GUIDE.md) - Complete guide to the dynamic TOC system
- [TOC_GUIDE.md](../TOC_GUIDE.md) - Original TOC customization guide