# Bank of Z

A sample z/OS banking application demonstrating modern mainframe development practices with COBOL, BMS, and IBM Dependency Based Build (DBB).

## Overview

Bank of Z is a CICS-based banking application that showcases:

- **COBOL Programs** - Core banking business logic for account management, customer operations, and transactions
- **BMS Maps** - Screen definitions for CICS terminal interactions
- **Copybooks** - Shared data structures and definitions
- **IBM DBB Integration** - Modern build automation for z/OS applications
- **Pipeline Simulation** - Automated build and deployment workflows

## Application Features

The application provides typical banking operations:

- **Account Management** - Create, update, delete, and inquire on accounts
- **Customer Management** - Manage customer information and profiles
- **Transaction Processing** - Handle debits, credits, and fund transfers
- **Menu Navigation** - User-friendly CICS interface for banking operations

## Project Structure

```
Bank-of-Z/
├── src/                          # Application source code
│   └── base/
│       ├── cobol/               # COBOL programs
│       ├── bms/                 # BMS map definitions
│       └── copy/                # Copybooks
├── .setup/                       # Pipeline setup automation
│   ├── config.yaml              # Environment configuration
│   ├── setup.sh                 # Setup script
│   ├── run_pipeline.sh          # Pipeline execution script
│   ├── pipeline_simulation.sh   # Pipeline simulation script
│   └── build/                   # zBuilder framework
├── .vscode/
│   └── tasks.json               # VS Code custom tasks
├── docs/
│   └── SETUP_GUIDE.md          # Detailed setup instructions
└── dbb-app.yaml                 # DBB application configuration
```

## Quick Start

### Prerequisites

**Local Machine:**
- [Node.js](https://nodejs.org/) and npm
- [Zowe CLI](https://docs.zowe.org/stable/user-guide/cli-installcli): `npm install -g @zowe/cli`
- Zowe RSE API Plugin: `zowe plugins install @zowe/rse-api-for-zowe-cli`
- Configured Zowe profile with z/OS connection details

**z/OS System:**
- Git installed and available in PATH on USS
- CICS region for application deployment
- IBM DBB installed (typically at `/usr/lpp/dbb`)
- Appropriate permissions for USS directories and dataset creation

### Setup Using VS Code Tasks

The easiest way to get started is using the built-in VS Code tasks:

1. **Configure Your Environment**
   
   Edit [`.setup/config.yaml`](.setup/config.yaml) with your z/OS details:
   ```yaml
   pipeline:
     workspace: /u/$USER/sandbox
     tmphlq: YOUR_HLQ
   ```

2. **Run Setup Task**
   
   - Press `Cmd+Shift+P` (macOS) or `Ctrl+Shift+P` (Windows/Linux)
   - Type "Tasks: Run Task"
   - Select **"Setup Pipeline Environment"**
   
   This will:
   - Create workspace directories on USS
   - Clone IBM DBB repository
   - Upload zBuilder framework

3. **Run Pipeline Simulation**
   
   - Press `Cmd+Shift+P` (macOS) or `Ctrl+Shift+P` (Windows/Linux)
   - Type "Tasks: Run Task"
   - Select **"Run Pipeline Simulation"**
   - Enter git repository URL and branch when prompted
   
   The pipeline will:
   - Clone your application repository
   - Build all COBOL programs and BMS maps
   - Create load modules
   - Generate build reports

## Documentation

- **[Setup Guide](docs/SETUP_GUIDE.md)** - Comprehensive setup instructions, troubleshooting, and customization
- **[Setup Directory README](.setup/README.md)** - Details on setup scripts and configuration
- **[Source Code README](src/README.md)** - Application source code structure

## Key Components

### COBOL Programs

Located in [`src/base/cobol/`](src/base/cobol/):

- **BNKMENU** - Main menu program
- **BNK1CAC, BNK1CCA, BNK1CCS** - Account creation and management
- **BNK1DAC, BNK1DCS** - Account deletion
- **BNK1UAC** - Account updates
- **BNK1TFN** - Fund transfers
- **CREACC, CRECUST** - Create account/customer
- **INQACC, INQCUST** - Inquiry programs
- **UPDACC, UPDCUST** - Update programs
- **DELACC, DELCUS** - Delete programs

### BMS Maps

Located in [`src/base/bms/`](src/base/bms/):

- **BNK1MAI** - Main menu map
- **BNK1ACC** - Account screen
- **BNK1CAM, BNK1CCM, BNK1CDM** - Account management maps
- **BNK1UAM, BNK1DAM, BNK1DCM** - Update/delete maps
- **BNK1TFM** - Transfer map

### Build Configuration

- **[`dbb-app.yaml`](dbb-app.yaml)** - DBB application configuration with impact analysis patterns
- **[`.setup/build/`](.setup/build/)** - zBuilder framework with language-specific build rules

## Development Workflow

1. **Make Changes** - Edit COBOL programs, BMS maps, or copybooks
2. **Commit Changes** - Push to your git repository
3. **Run Pipeline** - Execute via VS Code task or command line
4. **Review Results** - Check build output and load modules
5. **Deploy** - Use generated artifacts for CICS deployment

## Build System

The project uses IBM Dependency Based Build (DBB) with the zBuilder framework:

- **Incremental Builds** - Only changed programs are recompiled
- **Impact Analysis** - Automatically detects affected programs
- **Dependency Management** - Tracks copybook and BMS map dependencies
- **Language Support** - COBOL, BMS, and link cards

## Configuration

### Environment Variables

The pipeline simulation script uses these configurable variables:

- `PIPELINE_WORKSPACE` - Build workspace directory
- `DBB_REPO` - Path to DBB repository
- `DBB_BUILD_PATH` - Path to zBuilder framework
- `DBB_BUILD` - DBB build directory
- `TMPHLQ` - Temporary dataset high-level qualifier

All values are pulled from [`.setup/config.yaml`](.setup/config.yaml) and passed as environment variables.

### Dataset Configuration

Dataset allocations are defined in [`.setup/build/languages/Languages.yaml`](.setup/build/languages/Languages.yaml):

```yaml
variables:
  - name: MACLIB
    value: SYS1.MACLIB
  - name: SCEELKED
    value: CEE.SCEELKED
```

## Troubleshooting

Common issues and solutions:

- **Zowe CLI not found** - Install with `npm install -g @zowe/cli`
- **Connection failed** - Verify Zowe profile: `zowe zosmf check status`
- **Git not available on z/OS** - Contact system administrator to install git
- **Permission denied** - Check USS directory permissions and dataset access

See the [Setup Guide](docs/SETUP_GUIDE.md) for detailed troubleshooting steps.

## Contributing

This is a sample application for demonstration purposes. Feel free to:

- Fork the repository
- Customize for your environment
- Add new features or programs
- Share improvements

## Resources

- [IBM DBB Documentation](https://www.ibm.com/docs/en/dbb)
- [IBM DBB GitHub Repository](https://github.com/IBM/dbb)
- [Zowe CLI Documentation](https://docs.zowe.org/stable/user-guide/cli-using)
- [COBOL Programming Guide](https://www.ibm.com/docs/en/cobol-zos)
- [CICS Documentation](https://www.ibm.com/docs/en/cics-ts)

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.

---

**Getting Started:** Follow the [Setup Guide](docs/SETUP_GUIDE.md) to configure your environment and run your first build.
