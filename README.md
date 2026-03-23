# Bank of Z

## Overview

The Bank of Z provides a modern browser interface to manage a personal bank account. The application is hybrid – it drives IMS transactions that update a Db2 database for some customers and it drives CICS transactions that update the same Db2 database for other customers.

This hybrid application is the result of a merger of two banking systems into one. The Bank of Z UI routes requests based on customer number. In both cases, z/OS Connect enables the client to communicate with the transactional environment.

## Architecture

```mermaid
graph LR
    UI[Bank of Z UI]
    ZOS[z/OS Connect]
    
    BANKQ1["Bank of Q
    Money Transfer In"]
    BANKQ2["Bank of Q
    Money Transfer In"]
    
    subgraph CICS_Flow[" "]
        CICS[CICS]
        MQ1[MQ]
        DB2_CICS[("Money & Account Mgmt Db2 DB")]
    end
    
    subgraph IMS_Flow[" "]
        MQ2[MQ]
        IMS[IMS TM]
        DB2_IMS[("Money & Account Mgmt IMS DB")]
    end
    
    HISTDB[("Account History Db2 DB")]
    
    UI --> ZOS
    
    BANKQ1 --> MQ1
    ZOS -->|"CICS Path (Customers with ID Cnnnn)"| CICS
    MQ1 --> CICS
    CICS --> DB2_CICS
    CICS --> HISTDB
    
    BANKQ2 --> MQ2
    MQ2 --> IMS
    ZOS -->|"IMS Path (Customers with ID Innnn)"| IMS
    IMS --> DB2_IMS
    IMS --> HISTDB
    
    style UI fill:#e1f5ff
    style ZOS fill:#fff4e6
    style CICS fill:#f3e5f5
    style IMS fill:#f3e5f5
    style DB2_CICS fill:#e8f5e9
    style DB2_IMS fill:#e8f5e9
    style HISTDB fill:#e8f5e9
    style MQ1 fill:#fff9c4
    style MQ2 fill:#fff9c4
    style BANKQ1 fill:#ffebee
    style BANKQ2 fill:#ffebee
```

## Key Components

- **Bank of Z UI**: Modern browser-based interface for customer banking operations
- **z/OS Connect**: Enterprise API gateway enabling communication between the UI and mainframe transaction systems
- **CICS**: Transaction processing system for customers with IDs starting with 'C'
- **IMS TM**: Transaction Manager for customers with IDs starting with 'I'
- **Money and Account Management Db2 DB**: Shared database for account and transaction data
- **Money and Account Management IMS DB**: IMS database for account management
- **Account History Db2 DB**: Database storing historical account information
- **MQ**: Message queuing system for asynchronous communication with external systems
- **Bank of Q Money Transfer In**: External banking system for money transfers

## Customer Routing

- Customers with ID pattern **Cnnnn** → Routed to CICS
- Customers with ID pattern **Innnn** → Routed to IMS TM

## Build and Deploy Tools

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

```text
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
- [Java version 21 of IBM's Semeru Runtime](https://developer.ibm.com/languages/java/semeru-runtimes/downloads/)
- [Node.js](https://nodejs.org/) and npm
  - npm: ">=10.9.4 < 10.10.0"
    - `npm -v`
  - node: ">=22.22.1 < 23"
    - `node -v`
- [Zowe CLI](https://docs.zowe.org/stable/user-guide/cli-installcli): 
  - `npm install -g @zowe/cli@zowe-v3-lts`
- Zowe RSE API Plugin: 
  - `zowe plugins install @ibm/rse-api-for-zowe-cli`
- Configured Zowe profile with z/OS connection details

Here is a sample configuration for the Zowe profile. Change:
-  the 'host' line to match your z/OS host
- the 'account' line to match your TSO account on the host
- the 'logonProcedure' line to match your logon procedure on the host

and if you use non-default ports, you may have to change other lines as well.
Save the file in: `~/.zowe/zowe.config.json`
```json
{
  "$schema": "./zowe.schema.json",
  "profiles": {
    "BankOfZDemo": {
      "properties": {
        "host": "<your host>",
        "rejectUnauthorized": false
      },
      "secure": ["user", "password"],
      "profiles": {
        "rseapi": {
          "type": "rse",
          "properties": {
            "port": 8195,
            "basePath": "rseapi",
            "protocol": "https"
          }
        },
        "zosmf": {
          "type": "zosmf",
          "properties": {
            "port": 10443
          }
        },
        "ssh": {
          "type": "ssh",
          "properties": {
            "port": 22
          }
        },
        "tso": {
          "type": "tso",
          "properties": {
            "account": "<account>",
            "codePage": "1047",
            "logonProcedure": "<logon procedure>"
          }
        },        
        "zOpenDebug": {
          "type": "zOpenDebug",
          "properties": {
            "dpsPort": 8192,
            "rdsPort": 8194,
            "dpsContextRoot": "api/v1",
            "dpsSecured": true,
            "authenticationType": "basic",
            "uuid": "4267a0f6-b756-4f3c-b900-0b959b4567c3"
          }
        }
      }
    }
  },
  "defaults": {
    "zosmf": "BankOfZDemo.zosmf",
    "tso": "BankOfZDemo.tso",
    "ssh": "BankOfZDemo.ssh",
    "rse": "BankOfZDemo.rseapi",
    "zOpenDebug": "BankOfZDemo.zOpenDebug"
  },
  "autoStore": true
}
```

You can then test each connection. Example:
- `zowe zosmf check status`
- `zowe rse check status`
- ...

**z/OS System:**

- Git installed and available in PATH on USS
- CICS region for application deployment
- IBM DBB installed (typically at `/usr/lpp/IBM/dbb`)
- Appropriate permissions for USS directories and dataset creation

### Setup Using Bob

Install Bob IDE and required extensions:
- Zowe Explorer
- IBM Z Open Editor
- DB2/CICS/IMS/MQ Extensions


### Setup Using VS Code Tasks

The easiest way to get started is using the built-in VS Code tasks:

1. **Configure Your Environment**
   Edit [`.setup/config.yaml`](.setup/config.yaml) if you want to change the defaults, e.g.
   ```yaml
   pipeline_script:
     workspace: ~/sandbox
     tmphlq:
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

   - You must adpat this file before [pipeline_simulation.sh](.setup/pipeline_simulation.sh)  (TODO needs variables)
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
