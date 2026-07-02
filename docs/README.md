# Bank of Z Documentation

[![GitHub Pages](https://img.shields.io/badge/docs-GitHub%20Pages-blue)](https://ibm.github.io/Bank-of-Z/)

Official documentation for Bank of Z - a sample banking application that demonstres modern IBM Z development, DevSecOps, deployment, and modernization practices.

## 🌐 Live Documentation

Visit the documentation site: **https://ibm.github.io/Bank-of-Z/**

## 📚 About This Repository

This repository contains the source files and build system for the Bank of Z documentation website. The site uses Jekyll and GitHub Pages with a **dynamic Table of Contents (TOC)** system that automatically generates navigation from the documentation structure.

## 🚀 Quick Start

### For Documentation Writers

1. **Add/Edit DITA files** in the `Docs/` folder
2. **Run the conversion script**:
   ```bash
   python3 scripts/convert_dita_to_md.py
   ```
3. **Commit and push** your changes
4. **Wait 2-3 minutes** for GitHub Pages to rebuild

That's it! The TOC and navigation update automatically.

### For Developers

```bash
# Clone the repository
git clone https://github.com/IBM/Bank-of-Z.git
cd Bank-of-Z-doc

# Install dependencies
pip3 install pyyaml
bundle install  # For local Jekyll testing

# Convert DITA to Markdown
python3 scripts/convert_dita_to_md.py

# Test locally (optional)
bundle exec jekyll serve
# Visit http://localhost:4000/Bank-of-Z-doc/
```

## 📁 Repository Structure

```
Bank-of-Z-doc/
├── _config.yml                 # Jekyll configuration
├── _data/
│   └── toc.yml                 # Auto-generated TOC (don't edit manually)
├── _layouts/
│   └── default.html            # Page layout with dynamic sidebar
├── Docs/                       # 📝 Source DITA files (EDIT THESE)
│   ├── com.ibm.introduction.doc/
│   ├── com.ibm.installation.setup.doc/
│   ├── com.ibm.tutorials.doc/
│   └── ...
├── docs/                       # 🤖 Generated Markdown (auto-created)
│   ├── introduction/
│   ├── installation-and-setup/
│   └── ...
├── scripts/
│   └── convert_dita_to_md.py   # DITA to Markdown converter
├── .github/workflows/
│   └── convert-docs.yml        # Optional: Auto-conversion on push
└── index.md                    # Home page
```

## 🔄 Dynamic TOC System

### How It Works

1. **Source Files**: Write documentation in DITA XML format in `Docs/` folders
2. **Conversion**: Run `convert_dita_to_md.py` to convert DITA to Markdown
4. **Dynamic Navigation**: Jekyll reads `toc.yml` and renders the sidebar navigation

### Key Features

✅ **Fully Automatic**: TOC updates when you run the conversion script  
✅ **No Manual Editing**: Never touch `_data/toc.yml` manually  
✅ **Folder-Based**: Organization mirrors your `Docs/` folder structure  
✅ **Consistent**: Same navigation across all pages  
✅ **Easy Maintenance**: Add/remove/reorganize with simple folder operations  

### Documentation Sections

| Folder | Section |
|--------|---------|
| `about-bank-of-z` | About Bank of Z |
| `architecture` | Architecture |
| `installation-and-setup` | Installation and Setup |
| `tutorials` | Tutorials |
| `development-workflows` | Development Workflows |
| `reference` | Reference |
| `troubleshooting` | Troubleshooting |

4. Run the conversion script

### Reorganizing Content

Simply move DITA files between folders in `Docs/`, then run the conversion script. The TOC updates automatically!

## 🤖 Automation (Optional)

The repository includes a GitHub Actions workflow that can automatically convert DITA files when they're pushed:

- **File**: `.github/workflows/convert-docs.yml`
- **Trigger**: Manual or on push to `Docs/**/*.dita`
- **Action**: Runs conversion script and commits changes

To enable, ensure GitHub Actions has write permissions in your repository settings.

## 🧪 Local Testing

### Prerequisites

- Ruby (for Jekyll)
- Python 3.x
- Bundler

### Setup

```bash
# Install Ruby dependencies
bundle install

# Install Python dependencies
pip3 install pyyaml

# Run Jekyll locally
bundle exec jekyll serve

# Visit http://localhost:4000/Bank-of-Z-doc/
```

## 📝 Writing Documentation

### DITA Format

Documentation is written in DITA XML format. Example:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE topic PUBLIC "-//OASIS//DTD DITA Topic//EN" "topic.dtd">
<topic id="getting_started" xml:lang="en-us">
<title>Getting Started</title>
<body>
<section>
<title>Introduction</title>
<p>This guide will help you get started with Bank of Z.</p>
<ul>
<li>Step 1: Install prerequisites</li>
<li>Step 2: Clone the repository</li>
</ul>
</section>
</body>
</topic>
```

### Supported DITA Elements

The conversion script handles:
- Titles and headings
- Paragraphs and lists (including nested)
- External and internal links (`<xref>`)
- Trademarks (`<tm>`)
- File paths (`<filepath>`)
- Code formatting

## 🎨 Customization

### Styling

Edit `_layouts/default.html` to customize:
- Colors and fonts
- Sidebar appearance
- Navigation behavior
- Page layout

### TOC Structure

Edit `scripts/convert_dita_to_md.py` to customize:
- Section names and order
- URL structure
- Index page templates
- Conversion rules

## 🐛 Troubleshooting

### TOC Not Updating

**Solution**: Run `python3 scripts/convert_dita_to_md.py` and commit changes

### Missing Dependencies

```bash
pip3 install pyyaml
bundle install
```

### Links Not Working

Check that `baseurl` in `_config.yml` matches your GitHub Pages URL

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add/edit DITA files in `Docs/`
4. Run the conversion script
5. Commit your changes
6. Submit a pull request

## 📄 License

This documentation is part of the Bank of Z project. See the main repository for license information.

## 🔗 Related Links

- **[Bank of Z Repository](https://github.com/IBM/Bank-of-Z)** - Main application repository
- **[IBM Z Documentation](https://www.ibm.com/docs/en/zos)** - IBM Z platform documentation
- **[Jekyll Documentation](https://jekyllrb.com/docs/)** - Jekyll static site generator
- **[DITA Specification](https://www.oasis-open.org/committees/dita/)** - DITA XML standard

## 📧 Support

For questions or issues:
- Open an issue in this repository
- Check the [DYNAMIC_TOC_GUIDE.md](DYNAMIC_TOC_GUIDE.md) for detailed instructions
- Review existing documentation in the `docs/` folder

---

**Built with ❤️ using Jekyll, GitHub Pages, and Python**

*Last updated: 2026*
