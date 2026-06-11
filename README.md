# Bank of Z

## Overview

The Bank of Z provides a modern browser interface to manage a personal bank account. The application is hybrid – it drives IMS transactions that update a Db2 database for some customers and it drives CICS transactions that update the same Db2 database for other customers.

This hybrid application is the result of a merger of two banking systems into one. The Bank of Z UI routes requests based on customer number. In both cases, z/OS Connect enables the client to communicate with the transactional environment.

### Key Components

- **Bank of Z UI**: Modern browser-based interface for customer banking operations
- **z/OS Connect**: Enterprise API gateway enabling communication between the UI and mainframe transaction systems
- **CICS**: Transaction processing system for customers with IDs starting with 'C'
- **IMS TM**: Transaction Manager for customers with IDs starting with 'I'
- **Money and Account Management Db2 DB**: Shared database for account and transaction data
- **Money and Account Management IMS DB**: IMS database for account management
- **Account History Db2 DB**: Database storing historical account information
- **MQ**: Message queuing system for asynchronous communication with external systems
- **Bank of Q Money Transfer In**: External banking system for money transfers

### Application Features

The application provides typical banking operations:

- **Account Management** - Create, update, delete, and inquire on accounts
- **Customer Management** - Manage customer information and profiles
- **Transaction Processing** - Handle debits, credits, and fund transfers
- **Menu Navigation** - User-friendly CICS interface for banking operations

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

### Customer Routing

- Customers with ID pattern **Cnnnn** → Routed to CICS
- Customers with ID pattern **Innnn** → Routed to IMS TM

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

### Build and Deploy Tools

- **COBOL Programs** - Core banking business logic for account management, customer operations, and transactions
- **BMS Maps** - Screen definitions for CICS terminal interactions
- **Copybooks** - Shared data structures and definitions
- **IBM DBB Integration** - Modern build automation for z/OS applications
- **Pipeline Simulation** - Automated build and deployment workflows

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

- the 'host' line to match your z/OS host
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

Bank of Z requires a mainframe runtime environment.

- Appropriate permissions for USS directories and dataset creation
- Git installed and available in PATH on USS
- [zconfig](https://ibm.biz/zconfig-join) for provisioning the middleware configuration
  - CICS region for application deployment
- Db2 for z/OS
- IMS
- IBM DBB 3.0.5 installed (typically at `/usr/lpp/IBM/dbb`)
- ZOAU 1.4.1.0 installed (typically at `/usr/lpp/IBM/zoautil`)
- Wazi Deploy 3.0.7.3 installed (typically at `/global/opt/pyenv/gdp`)
- ZCodeScan 1.0.2 installed (typically at `/global/opt/pyenv/akf`)
- [CICS TS Resource Builder](https://www.ibm.com/docs/en/cics-resource-builder/1.0.x?topic=installing-planning-installation-cics-ts-resource-builder)

### Setup IDE

If a `VS Code` or `Open VSX` link available, the extension can be installed via the marketplace, with Bob IDE using the Open VSX marketplace.  If setting up the Bob IDE environment and the extension is not avaialble in the Open VSX Marketplace use the `Download VSIX` link to download the extensions .vsix from the VS Code Marketplace and [manually install it in the IDE](#manual-installation-of-vsix).

Install Bob IDE and/or VS Code IDE and required extensions:

| Extension Name | VS Code Marketplace | Open VSX Marketplace | Download VSIX |
|----------------|---------------------|----------------------|---------------|
| IDzEE Extension Pack<br/>• IBM Z Open Editor<br/>• IBM Z Open Debug<br/>• IBM Compiled Code Coverage<br/>• Zowe Explorer<br/>• Zowe Explorer for IBM CICS Transaction Server | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.developer-for-zos-on-vscode-extension-pack) | [Link](https://open-vsx.org/extension/IBM/developer-for-zos-on-vscode-extension-pack) | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/developer-for-zos-on-vscode-extension-pack/latest/vspackage) |
| CICS Interdependency Analyzer Extension for Zowe Explorer | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.cics-ia-extension-for-zowe) | N/A | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/cics-ia-extension-for-zowe/latest/vspackage) |
| IBM IMS Explorer for VS Code | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.ims-explorer-for-vscode) | N/A | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/ims-explorer-for-vscode/latest/vspackage) |
| IBM Db2 for z/OS Developer Extension | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.db2forzosdeveloperextension) | [Link](https://open-vsx.org/extension/IBM/db2forzosdeveloperextension) | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/db2forzosdeveloperextension/latest/vspackage) |
| IBM z/OS Connect development tools | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.ibm-zosconnect) | N/A | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/ibm-zosconnect/latest/vspackage) |
| IBM TAZ Early Development Testing | [Link](https://marketplace.visualstudio.com/items?itemName=IBM.taz-edt-extension) | [Link](https://open-vsx.org/extension/IBM/taz-edt-extension) | [Link](https://marketplace.visualstudio.com/_apis/public/gallery/publishers/IBM/vsextensions/taz-edt-extension/latest/vspackage) |

**Note:** For MQ, there is no IBM extension in the VS Code marketplace. See IBM docs for [IBM MQ Console within Visual Studio Code's built-in browser](https://community.ibm.com/community/user/blogs/dorothy-quincy/2026/05/08/ibm-mq-console-extension) that links to an extension in the github.com/ibm-messaging group.

**Note:** Automated scripts require Node.js (version 22.22.1 or higher recommended)

#### Automated Download of all VSIX packages

Run the following command in the root of the repository:

```bash
node scripts/download-vsix.js [output-directory]
```

Default output directory is `./vsix-extensions`

#### Automated Installation of VSIX into Bob IDE

The following command will require the `bobide` command line tool installed and on the PATH. To do this from the Bob IDE GUI:

- Open the command palette by selecting `View` -> `Command Palette`, then type `Shell Command: Install 'bobide' command in PATH`

Run the following command in the root of the repository, no need to pass an output directory if default was used for download:

```bash
node scripts/install-bobide-vsix.js [output-directory]
```

#### Automated Installation of VSIX into VS Code

The following command will require the `code` command line tool installed and on the PATH. To do this from the VS Code GUI:

- Open the command palette by selecting `View` -> `Command Palette`, then type `Shell Command: Install 'code' command in PATH`

Run the following command in the root of the repository, no need to pass an output directory if default was used for download:

```bash
node scripts/install-vscode-vsix.js [output-directory]
```

For more information regarding the download and install scripts see [scripts/README.md](scripts/README.md).


#### Manual Installation of VSIX

To manually install the extension into the Bob IDE or VS Code:

- Select the extensions icon located in the Activity Bar on the left side of the IDE.  
- Select the `...` icon for `Views and More Actions...`
- Select `Install from VSIX...` choosing the download location of the extension from VS Code Marketplace in the file picker.

### Build and Install Bank of Z

### Setup Bank of Z

- Take a fork this repository, or move it into your own git provider
- Follow the initial setup instuctions in [docs/README.md](docs/README.md) to install and configure Bank of Z to your own runtime environment.

## Tutorials

After setting up Bank of Z in your environment, you can exercise the following developer tasks:

### Development Workflow

1. **Make Changes** - Edit COBOL programs, BMS maps, or copybooks
2. **Commit Changes** - Push to your git repository
3. **Run Pipeline** - Execute via VS Code task or command line
4. **Review Results** - Check build output and load modules
5. **Deploy** - Use generated artifacts for CICS deployment

### Implement Testing practises

## Documentation

- **[Setup Guide](docs/README.md)** - Comprehensive setup instructions, troubleshooting, and customization
- **[Source Code README](src/README.md)** - Application source code structure

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
