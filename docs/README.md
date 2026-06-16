# Bank of Z - Setup Guide

Automated setup for the Bank of Z pipeline simulation environment on z/OS USS.

## 🎯 Overview

This setup automates the preparation of your z/OS USS environment for Bank of Z development by:
- Creating workspace directories
- Cloning required repositories (DBB accelerators)
- Deploying the zBuilder framework
- Installing the Bank of Z application

**Key Feature**: Two complementary scripts that work together to support different workflows.

## 📋 Prerequisites

### For All Workflows
- z/OS USS access with appropriate permissions
- Git installed on z/OS USS
- Network connectivity to GitHub
- Main configuration file `.setup/config/config.yaml`

### Additionally for VSCode Task Workflows
- Zowe CLI installed: `npm install -g @zowe/cli`
- Zowe RSE API plugin: `zowe plugins install @zowe/rse-api-for-zowe-cli`
- Configured Zowe profile for your z/OS system

## 🚀 Quick Start


⚠️⚠️**NOTES**⚠️⚠️:
- If you don't use `IBMUSER`  you need to grant your user for database creation.
  Edit [../.setup/jcl/Db2-grant.jcl](../.setup/jcl/Db2-grant.jcl) and replace `MYUSER`with your user. Then issue the commands:
   
   ```bash
   JOBID=$(jsub -f .setup/jcl/Db2-grant.jcl)
   jls $JOBID # CC must be 0004 max
   pjdd $JOBID SYSPRINT
   ```
- During the static scan step of the pipeline simulation flow, you must create the ZCodeScan configuration file
  using the **ISO8859-1** encoding. By default, the `zcs_config_file.yml file must be located in your home directory.`
  You can change the default in [../.setup/config/config.yaml](../.setup/config/config.yaml). Example:
  
  ```yaml
  license_server:
    url: https://127.0.0.1:8195
    user: IBMUSER
    password: MY_PASSWORD
    verify: false
  ``` 
  The password will be encrypted after the very first scan.

### Option 1: Setup & Install via terminal

**Best for**: Direct USS access, users without access to GRUB or ZOWE CLI for custom tasks

1. SSH to z/OS USS
    ```bash
    ssh user@zos-host
    ```

1. Define your working directory

   This path will be used for subsequent setup operations:
   ```bash
   export BANK_OF_Z_WORK_DIR=/usr/local/sandboxes/bank-of-z
   ```

1. Create working directory
   ```bash
   mkdir -p $BANK_OF_Z_WORK_DIR
   ```

1. Clone repository
   ```bash
   cd $BANK_OF_Z_WORK_DIR
   git clone https://github.com/ibm/Bank-of-Z.git
   cd Bank-of-Z
   ```

1. Edit configuration according to your environment setup

   Feel free to use ZOWE Explorer or other ways to edit the configuration file [../.setup/config/config.yaml](../.setup/config/config.yaml).
   ```bash
   vi .setup/config/config.yaml
   ```

1. Validate prerequisites
   ```bash
   .setup/setup-common.sh validate-prereqs
   ```

   <details>
   <summary>Sample output</summary>
   
   ```
   .setup/setup-common.sh validate-prereqs

   =================================================================
   = Detecting Bank of Z location...
   =================================================================

   [INFO] Running from within Bank-of-Z repository
   [INFO] Repository location: /usr/local/sandboxes/bank-of-z/Bank-of-Z
   [SUCCESS] Using current repository (GRUB workflow detected)

   [INFO] Running on: z/OS VS01 02.00 03 8561


   =================================================================
   = STAGE 1: Validate Installation
   =================================================================

   [INFO] Running Bank of Z installation validation script...
   [INFO] Executing: bash /usr/local/sandboxes/bank-of-z/Bank-of-Z/.setup/setup/validate-install.sh
   [INFO] [VALIDATE] =========================================
   [INFO] [VALIDATE] Checking DBB Runtime Environment
   [INFO] [VALIDATE] =========================================
   [INFO] [VALIDATE] DBB Output:
   [INFO] [VALIDATE]   Dependency Based Build version 3.0.4.1
   [INFO] [VALIDATE]   build 770 (20-Jan-2026 14:33:42)
   [INFO] [VALIDATE]   JVM: 21.0.9 | Vendor: IBM Corporation | OS: z/OS
   [INFO] [VALIDATE] Detected DBB version: 3.0.4.1
   [INFO] [VALIDATE] Minimum required version: 3.0.4.1
   [SUCCESS] [VALIDATE] DBB version check PASSED
   [INFO] [VALIDATE] =========================================
   [INFO] [VALIDATE] Checking ZOAU Installation
   [INFO] [VALIDATE] =========================================
   [INFO] [VALIDATE] ZOAU Output:
   [INFO] [VALIDATE]   2026/02/27 09:00:18 CUT v1.4.1.0 0ac8584c 9167 PH68100 1703 707fd734
   [INFO] [VALIDATE] Detected ZOAU version: 1.4.1.0
   [INFO] [VALIDATE] Minimum required version: 1.4.1.0
   [SUCCESS] [VALIDATE] ZOAU version check PASSED
   [INFO] [VALIDATE] =========================================
   [INFO] [VALIDATE] Checking zconfig Installation
   [INFO] [VALIDATE] =========================================
   [INFO] [VALIDATE] Found zconfig activation script: /usr/local/sandboxes/tools/zconfig/bin/activate
   [INFO] [VALIDATE] zconfig Output:
   [INFO] [VALIDATE]   TYPE           CONFIG TASK ID           LAST UPDATED                 
   [INFO] [VALIDATE]   cics_region    cics_region://CICSBOZ    2026-06-01T04:42:59-04:00
   [SUCCESS] [VALIDATE] zconfig installation check PASSED
   [INFO] [VALIDATE] =========================================
   [INFO] [VALIDATE] Checking Wazi Deploy Installation
   [INFO] [VALIDATE] =========================================
   [INFO] [VALIDATE] Found Wazi Deploy activation script: /global/opt/pyenv/gdp/bin/activate
   [INFO] [VALIDATE] Wazi Deploy Output:
   [INFO] [VALIDATE]   Version: 3.0.7.3
   [INFO] [VALIDATE]   Build Number: 4447
   [INFO] [VALIDATE]   Build Date: Tue May 26 10:02:55 UTC 2026
   [INFO] [VALIDATE] Detected Wazi Deploy version: 3.0.7.3
   [INFO] [VALIDATE] Minimum required version: 3.0.7.1
   [SUCCESS] [VALIDATE] Wazi Deploy version check PASSED
   [INFO] [VALIDATE] =========================================
   [INFO] [VALIDATE] Validation Summary
   [INFO] [VALIDATE] =========================================
   [INFO] [VALIDATE] Checks passed:  4
   [INFO] [VALIDATE] Checks failed:  0
   [INFO] [VALIDATE] Warnings:       0
   [SUCCESS] [VALIDATE] All validation checks PASSED
   [SUCCESS] Installation validation completed successfully

   =================================================================
   = VALIDATION COMPLETE
   =================================================================
   ```
   </details>


1. Run setup of middleware systems
   This sets up Db2 tables, a new CICS region and z/OS Connect instance via zConfig
    ```bash
    .setup/setup-common.sh environment
    ```
   <details>
   <summary>Sample output</summary>

   ```
   .setup/setup-common.sh environment     

   =================================================================
   = Detecting Bank of Z location...
   =================================================================

   [INFO] Running from within Bank-of-Z repository
   [INFO] Repository location: /usr/local/sandboxes/bank-of-z/Bank-of-Z
   [SUCCESS] Using current repository (GRUB workflow detected)

   [INFO] Running on: z/OS VS01 02.00 03 8561


   =================================================================
   = STAGE 1: Clone Required Accelerators
   =================================================================

   [INFO] Cloning DBB repository...
   [INFO] Repository: https://github.com/IBM/dbb.git
   [INFO] Target: /usr/local/sandboxes/bank-of-z/dbb
   [INFO] Checking git availability...
   [SUCCESS] Git is available
   [SUCCESS] Existing dbb directory removed
   [INFO] Cloning repository (this may take a few minutes)...
   Cloning into 'dbb'...
   remote: Enumerating objects: 3238, done.
   remote: Counting objects: 100% (691/691), done.
   remote: Compressing objects: 100% (510/510), done.
   remote: Total 3238 (delta 481), reused 184 (delta 181), pack-reused 2547 (from 3)
   Receiving objects: 100% (3238/3238), 7.82 MiB | 14.72 MiB/s, done.
   Resolving deltas: 100% (1759/1759), done.
   [SUCCESS] DBB repository cloned successfully
   [SUCCESS] Repository verification successful

   =================================================================
   = STAGE 2: Copy Build Framework
   =================================================================

   [INFO] Datasets configuration from datasets.yaml:


   [INFO] Copying zBuilder framework...
   [INFO] Source: /usr/local/sandboxes/bank-of-z/Bank-of-Z/.setup/build
   [INFO] Target: /usr/local/sandboxes/bank-of-z/zBuilder
   [SUCCESS] Existing zBuilder directory removed
   [INFO] Ensuring parent directory exists: /usr/local/sandboxes/bank-of-z
   [INFO] Copying zBuilder framework files...
   [SUCCESS] zBuilder framework copied successfully
   [SUCCESS] zBuilder framework setup completed successfully

   =================================================================
   = STAGE 3: Create DB2 database
   =================================================================

   [INFO] Running Bank of Z database setup script...
   [INFO] Executing: bash /usr/local/sandboxes/bank-of-z/Bank-of-Z/.setup/setup/setup-db2-tables.sh
   ==> Submitting /tmp/Db2-drop.jcl.33555577 via jsub...
   JOB00157
   Waiting for job JOB00157...
   IBMUSER  DB2DROP  JOB00157 AC           ? 
   IBMUSER  DB2DROP  JOB00157 CC        0000 
   IBMUSER  DB2DROP  JOB00157 CC        0000 
   ===== JESYSMSG =====
   ICH70001I IBMUSER  LAST ACCESS AT 11:37:43 ON WEDNESDAY, JUNE 3, 2026
   IEFA111I DB2DROP IS USING THE FOLLOWING JOB RELATED SETTINGS:
            SWA=BELOW,TIOT SIZE=64K,DSENQSHR=DISALLOW,GDGBIAS=JOB
   IEF236I ALLOC. FOR DB2DROP GRANT
   IGD103I SMS ALLOCATED TO DDNAME JOBLIB
   IEF237I JES2 ALLOCATED TO SYSTSPRT
   IEF237I JES2 ALLOCATED TO SYSPRINT
   IEF237I JES2 ALLOCATED TO SYSUDUMP
   IEF237I JES2 ALLOCATED TO SYSTSIN
   IEF237I JES2 ALLOCATED TO SYSIN
   IGD103I SMS ALLOCATED TO DDNAME SYS00001
   IGD104I DBD1.RUNLIB.LOAD                             RETAINED,  DDNAME=SYS00001
   IEF142I DB2DROP GRANT - STEP WAS EXECUTED - COND CODE 0000
   IEF285I   IBMUSER.DB2DROP.JOB00157.D0000103.?          SYSOUT        
   IEF285I   IBMUSER.DB2DROP.JOB00157.D0000104.?          SYSOUT        
   IEF285I   IBMUSER.DB2DROP.JOB00157.D0000105.?          SYSOUT        
   IEF285I   IBMUSER.DB2DROP.JOB00157.D0000101.?          SYSIN         
   IEF285I   IBMUSER.DB2DROP.JOB00157.D0000102.?          SYSIN         
   IEF373I STEP/GRANT   /START 2026154.1143
   IEF032I STEP/GRANT   /STOP  2026154.1143 
            CPU:     0 HR  00 MIN  00.04 SEC    SRB:     0 HR  00 MIN  00.00 SEC    
            VIRT:   568K  SYS:   412K  EXT:     6108K  SYS:    10680K
            ATB- REAL:                   228K  SLOTS:                     0K
               VIRT- ALLOC:      13M SHRD:       0M
   IGD104I DB2V13.SDSNLOAD                              RETAINED,  DDNAME=JOBLIB  
   IEF375I  JOB/DB2DROP /START 2026154.1143
   IEF033I  JOB/DB2DROP /STOP  2026154.1143 
            CPU:     0 HR  00 MIN  00.04 SEC    SRB:     0 HR  00 MIN  00.00 SEC    
   ==> Submitting /tmp/Db2-create.jcl.33555577 via jsub...
   JOB00158
   Waiting for job JOB00158...
   IBMUSER  DB2CREAT JOB00158 AC           ? 
   IBMUSER  DB2CREAT JOB00158 CC        0000 
   IBMUSER  DB2CREAT JOB00158 CC        0000 
   ===== JESYSMSG =====
   ICH70001I IBMUSER  LAST ACCESS AT 11:43:39 ON WEDNESDAY, JUNE 3, 2026
   IEFA111I DB2CREAT IS USING THE FOLLOWING JOB RELATED SETTINGS:
            SWA=BELOW,TIOT SIZE=64K,DSENQSHR=DISALLOW,GDGBIAS=JOB
   IEF236I ALLOC. FOR DB2CREAT GRANT
   IGD103I SMS ALLOCATED TO DDNAME JOBLIB
   IEF237I JES2 ALLOCATED TO SYSTSPRT
   IEF237I JES2 ALLOCATED TO SYSPRINT
   IEF237I JES2 ALLOCATED TO SYSUDUMP
   IEF237I JES2 ALLOCATED TO SYSTSIN
   IEF237I JES2 ALLOCATED TO SYSIN
   IGD103I SMS ALLOCATED TO DDNAME SYS00001
   IGD104I DBD1.RUNLIB.LOAD                             RETAINED,  DDNAME=SYS00001
   IEF142I DB2CREAT GRANT - STEP WAS EXECUTED - COND CODE 0000
   IEF285I   IBMUSER.DB2CREAT.JOB00158.D0000103.?         SYSOUT        
   IEF285I   IBMUSER.DB2CREAT.JOB00158.D0000104.?         SYSOUT        
   IEF285I   IBMUSER.DB2CREAT.JOB00158.D0000105.?         SYSOUT        
   IEF285I   IBMUSER.DB2CREAT.JOB00158.D0000101.?         SYSIN         
   IEF285I   IBMUSER.DB2CREAT.JOB00158.D0000102.?         SYSIN         
   IEF373I STEP/GRANT   /START 2026154.1143
   IEF032I STEP/GRANT   /STOP  2026154.1143 
            CPU:     0 HR  00 MIN  00.03 SEC    SRB:     0 HR  00 MIN  00.00 SEC    
            VIRT:   568K  SYS:   412K  EXT:     6108K  SYS:    10680K
            ATB- REAL:                   228K  SLOTS:                     0K
               VIRT- ALLOC:      13M SHRD:       0M
   IGD104I DB2V13.SDSNLOAD                              RETAINED,  DDNAME=JOBLIB  
   IEF375I  JOB/DB2CREAT/START 2026154.1143
   IEF033I  JOB/DB2CREAT/STOP  2026154.1143 
            CPU:     0 HR  00 MIN  00.03 SEC    SRB:     0 HR  00 MIN  00.00 SEC    
   [SUCCESS] Bank of Z application setup completed successfully

   =================================================================
   = STAGE 4: Create CICS region with zconfig
   =================================================================

   [INFO] Running Bank of Z database setup script...
   [INFO] Executing: bash /usr/local/sandboxes/bank-of-z/Bank-of-Z/.setup/setup/setup-cics-region.sh
   [INFO] [ZCONFIG-INSTALL] VS01       2026154  11:43:52.00             ISF031I CONSOLE IBMU0000 ACTIVATED
   [INFO] [ZCONFIG-INSTALL] VS01       2026154  11:43:52.00            -C CICSBOZ
   [INFO] [ZCONFIG-INSTALL] VS01       2026154  11:43:52.00             IEE301I CICSBOZ           CANCEL COMMAND ACCEPTED
   [INFO] [ZCONFIG-INSTALL] ALLOC DA('BANKZ.V0R1M0.LOADLIB') NEW CATALOG DSNTYPE(LIBRARY) DSORG(PO) RECFM(U) BLKSIZE(32760) SPACE(5,5) CYL DIR(20)
   [INFO] [ZCONFIG-INSTALL] 
   [INFO] [ZCONFIG-INSTALL] =================================================================
   [INFO] [ZCONFIG-INSTALL] = STAGE 1: Create JVM profile file
   [INFO] [ZCONFIG-INSTALL] =================================================================
   [INFO] [ZCONFIG-INSTALL] 
   [INFO] [ZCONFIG-INSTALL] [SUCCESS] JVM profile file created successfully!
   [INFO] [ZCONFIG-INSTALL] 
   [INFO] [ZCONFIG-INSTALL] =================================================================
   [INFO] [ZCONFIG-INSTALL] = STAGE 2: Create CICS resource overrides file
   [INFO] [ZCONFIG-INSTALL] =================================================================
   [INFO] [ZCONFIG-INSTALL] 
   [INFO] [ZCONFIG-INSTALL] [SUCCESS] Overrides file created successfully!
   [INFO] [ZCONFIG-INSTALL] 
   [INFO] [ZCONFIG-INSTALL] =================================================================
   [INFO] [ZCONFIG-INSTALL] = STAGE 3: Create CICS instance with zconfig
   [INFO] [ZCONFIG-INSTALL] =================================================================
   [INFO] [ZCONFIG-INSTALL] 
   [INFO] [ZCONFIG-INSTALL] OUTPUT   JVM profile created successfully at '/usr/local/sandboxes/bank-of-z/CICSBOZ/JVMProfiles/EYUSMSSJ.jvmprofile'                               
   [INFO] [ZCONFIG-INSTALL] OUTPUT   Successfully created data set: 'BANKZ.CICSBOZ.DFHLRQ'                                                                                      
   [INFO] [ZCONFIG-INSTALL] OUTPUT   Successfully created and initialized data set: 'BANKZ.CICSBOZ.DFHLCD'                                                                      
   [INFO] [ZCONFIG-INSTALL] OUTPUT   Successfully created data set: 'BANKZ.CICSBOZ.DFHTEMP'                                                                                     
   [INFO] [ZCONFIG-INSTALL] OUTPUT   Successfully created data set: 'BANKZ.CICSBOZ.DFHINTRA'                                                                                    
   [INFO] [ZCONFIG-INSTALL] OUTPUT   Successfully created data set: 'BANKZ.CICSBOZ.DFHDMPB'                                                                                     
   [INFO] [ZCONFIG-INSTALL] OUTPUT   Successfully created data set: 'BANKZ.CICSBOZ.DFHAUXT'                                                                                     
   [INFO] [ZCONFIG-INSTALL] OUTPUT   Successfully created data set: 'BANKZ.CICSBOZ.DFHBUXT'                                                                                     
   [INFO] [ZCONFIG-INSTALL] OUTPUT   Successfully created data set: 'BANKZ.CICSBOZ.DFHDMPA'                                                                                     
   [INFO] [ZCONFIG-INSTALL] OUTPUT   Successfully created data set: 'BANKZ.CICSBOZ.DFHSTART'                                                                                    
   [INFO] [ZCONFIG-INSTALL] OUTPUT   Successfully created and initialized data set: 'BANKZ.CICSBOZ.DFHGCD'                                                                      
   [INFO] [ZCONFIG-INSTALL] WARNING  Executing DFHCSDUP on 'BANKZ.CICSBOZ.DFHCSD' raised a warning. For more information, see the log:                                          
   [INFO] [ZCONFIG-INSTALL]          '/u/ibmuser/.zconfig/logs/cics_region_CICSBOZ-2026-06-03T11:44:12.139233.txt'                                                              
   [INFO] [ZCONFIG-INSTALL] OUTPUT   Successfully created and initialized data set: 'BANKZ.CICSBOZ.DFHCSD'                                                                      
   [INFO] [ZCONFIG-INSTALL]   Applying configuration... ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 100% 0:00:00 0:00:16[SUCCESS] ZConfig completed successfully!
   [INFO] [ZCONFIG-INSTALL] 
   [INFO] [ZCONFIG-INSTALL] =================================================================
   [INFO] [ZCONFIG-INSTALL] = STAGE 4: Start CICS region
   [INFO] [ZCONFIG-INSTALL] =================================================================
   [INFO] [ZCONFIG-INSTALL] 
   [INFO] [ZCONFIG-INSTALL] JOB00179
   [INFO] [ZCONFIG-INSTALL] [INFO] [ZCONFIG-INSTALL] CICS Region Job Started
   [SUCCESS] Bank of Z application setup completed successfully

   =================================================================
   = STAGE 5: Setup zOS Connect server
   =================================================================

   [INFO] Running Bank of Z zOS Connect server setup script...
   [INFO] Executing: bash /usr/local/sandboxes/bank-of-z/Bank-of-Z/.setup/setup/setup-zosconnect-server.sh

   =================================================================
   = Create z/OS Connect Server
   =================================================================

   [INFO] [ZOSCONNECT] Creating z/OS Connect server at: /usr/local/sandboxes/bank-of-z/zosconnect-server
   [WARNING] Removing existing server at /usr/local/sandboxes/bank-of-z/zosconnect-server

   Server bankzServer created.
   [SUCCESS] z/OS Connect server created successfully at /usr/local/sandboxes/bank-of-z/zosconnect-server
   [INFO] [ZOSCONNECT] Configuring RACF STARTED profile...
   VS01       2026154  11:45:00.00             ISF031I CONSOLE IBMU0000 ACTIVATED
   VS01       2026154  11:45:00.00            -C BAQBANKZ
   VS01       2026154  11:45:00.00             IEE301I BAQBANKZ          CANCEL COMMAND ACCEPTED
   [INFO] [ZOSCONNECT] Defining RACF STARTED class...
   ICH10102I BAQBANKZ.* ALREADY DEFINED TO CLASS STARTED.
   [INFO] [ZOSCONNECT] Refreshing RACF...
   [INFO] [ZOSCONNECT] Removing old PROCLIB member...
   [INFO] [ZOSCONNECT] Generating JCL proc...
   [INFO] [ZOSCONNECT] Copying JCL to SYS1.PROCLIB...
   VS01       2026154  11:45:08.00             ISF031I CONSOLE IBMU0000 ACTIVATED
   VS01       2026154  11:45:08.00            -S BAQBANKZ
   VS01       2026154  11:45:08.00             
   [SUCCESS] z/OS Connect server setup completed
   [SUCCESS] Bank of Z application setup completed successfully

   =================================================================
   = SETUP COMPLETE
   =================================================================

   [SUCCESS] Environment setup completed successfully!

   [INFO] Next step: run this script in build-baseline mode to build and deploy the Bank of Z baseline.
   ```
   </details>
1. Run setup of working
   Building and deploying the Bank of Z application as a baseline to the provisioned system
    ```bash
    .setup/setup-common.sh install-bank-of-z
    ```
   <details><summary>Example Output</summary>

   ```
   .setup/setup-common.sh install-bank-of-z

   =================================================================
   = Detecting Bank of Z location...
   =================================================================

   [INFO] Running from within Bank-of-Z repository
   [INFO] Repository location: /usr/local/sandboxes/bank-of-z/Bank-of-Z
   [SUCCESS] Using current repository (GRUB workflow detected)
   chmod: FSUM6180 file "/usr/local/sandboxes/bank-of-z/Bank-of-Z/.setup/pipeline-common.sh": EDC5129I No such file or directory.
   (gdp) (zconfig) IBMUSER:/usr/local/sandboxes/bank-of-z/Bank-of-Z # .setup/setup-common.sh install-bank-of-z

   =================================================================
   = Detecting Bank of Z location...
   =================================================================

   [INFO] Running from within Bank-of-Z repository
   [INFO] Repository location: /usr/local/sandboxes/bank-of-z/Bank-of-Z
   [SUCCESS] Using current repository (GRUB workflow detected)

   =================================================================
   = STAGE 1: Build Bank of Z
   =================================================================

   [INFO] Running Bank of Z build script...
   [INFO] Executing: bash /usr/local/sandboxes/bank-of-z/Bank-of-Z/.setup/tasks/task-dbb-build.sh
   [INFO] [DBB-BUILD] Running FULL DBB build
   [INFO] [DBB-BUILD] Starting DBB build in /usr/local/sandboxes/bank-of-z/Bank-of-Z/ ...
   [INFO] [DBB-BUILD] IBM Dependency Based Build 3.0.4.1
   [INFO] [DBB-BUILD] 
   [INFO] [DBB-BUILD] BUILD
   [INFO] [DBB-BUILD] 
   [INFO] [DBB-BUILD] Lifecycle: full
   [INFO] [DBB-BUILD] Build start at 20260603.114759.608
   [INFO] [DBB-BUILD] Started by 'IBMUSER' on 'VS01'
   [INFO] [DBB-BUILD] Task: Start
   [INFO] [DBB-BUILD] Task: ScannerInit
   [INFO] [DBB-BUILD] Task: MetadataInit
   [INFO] [DBB-BUILD] Type: file
   [INFO] [DBB-BUILD] Location: '/usr/local/sandboxes'
   [INFO] [DBB-BUILD] Group: BANKZ-main
   [INFO] [DBB-BUILD] Task: FullAnalysis
   [INFO] [DBB-BUILD] [main] WARN com.ibm.dbb.task.framework.FullAnalysis - BGZZB0021E Scanning failed for build file "Bank-of-Z/src/api/src/main/webapp/META-INF/openapi.yaml" with error:
   [INFO] [DBB-BUILD] BGZTK0128E No dependency scanner was located for Bank-of-Z/src/api/src/main/webapp/META-INF/openapi.yaml
   [INFO] [DBB-BUILD] [main] WARN com.ibm.dbb.task.framework.FullAnalysis - BGZZB0021E Scanning failed for build file "Bank-of-Z/src/api/src/main/api/openapi.yaml" with error:
   [INFO] [DBB-BUILD] BGZTK0128E No dependency scanner was located for Bank-of-Z/src/api/src/main/api/openapi.yaml
   [INFO] [DBB-BUILD] [main] WARN com.ibm.dbb.task.framework.FullAnalysis - BGZZB0021E Scanning failed for build file "Bank-of-Z/zcodescan/zcodescan-rules.yaml" with error:
   [INFO] [DBB-BUILD] BGZTK0128E No dependency scanner was located for Bank-of-Z/zcodescan/zcodescan-rules.yaml
   [INFO] [DBB-BUILD] Stage: Languages
   [INFO] [DBB-BUILD] Language: BMS
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/bms/BNK1ACC.bms'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/bms/BNK1B2M.bms'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/bms/BNK1CAM.bms'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/bms/BNK1CCM.bms'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/bms/BNK1CDM.bms'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/bms/BNK1DAM.bms'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/bms/BNK1DCM.bms'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/bms/BNK1MAI.bms'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/bms/BNK1TFM.bms'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/bms/BNK1UAM.bms'
   [INFO] [DBB-BUILD] Language: Cobol
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/ABNDPROC.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/BANKDATA.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/BNK1CAC.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/BNK1CCA.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/BNK1CCS.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/BNK1CRA.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/BNK1DAC.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/BNK1DCS.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/BNK1TFN.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/BNK1UAC.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/BNKMENU.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/CRDTAGY1.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/CRDTAGY2.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/CRDTAGY3.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/CRDTAGY4.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/CRDTAGY5.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/CREACC.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/CRECUST.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/DBCRFUN.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/DELACC.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/DELCUS.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/GETCOMPY.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/GETSCODE.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/INQACC.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/INQACCCU.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/INQCUST.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/UPDACC.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/UPDCUST.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/cics/cobol/XFRFUN.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/cobol/IBACSUM.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/cobol/IBGCUDAT.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/cobol/IBLOGIN1.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/cobol/IBLOGOUT.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/cobol/IBSCUDAT.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/cobol/IBTRAN.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/cobol/LOADACCT.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/cobol/LOADCUSA.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/cobol/LOADCUST.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/cobol/LOADHIST.cbl'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/cobol/LOADTSTA.cbl'
   [INFO] [DBB-BUILD] Language: Assembler
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/DBD/ACCOUNT.asm'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/DBD/ACCTYPE.asm'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/DBD/CUSTACCS.asm'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/DBD/CUSTOMER.asm'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/DBD/CUSTTYPE.asm'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/DBD/HISTORY.asm'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/DBD/TSTAT.asm'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/DBD/TSTATTYP.asm'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/DBD/TTYPE.asm'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/PSB/IB.asm'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/PSB/IBACSUM.asm'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/PSB/IBGCUDAT.asm'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/PSB/IBLOAD.asm'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/PSB/IBLOGIN.asm'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/PSB/IBLOGOUT.asm'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/PSB/IBSCUDAT.asm'
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/PSB/IBTRAN.asm'
   [INFO] [DBB-BUILD] Language: PLI
   [INFO] [DBB-BUILD] Building 'Bank-of-Z/src/base/ims/pli/IBLOGIN.pli'
   [INFO] [DBB-BUILD] Task: VanillaFrontend
   [INFO] [DBB-BUILD] Task: ServerXmlPackager
   [INFO] [DBB-BUILD] Task: zOSConnect
   [INFO] [DBB-BUILD] Building project configuration Bank-of-Z/src/api/src/main/api/openapi.yaml
   [INFO] [DBB-BUILD] Task: Package
   [INFO] [DBB-BUILD] Generated package 'Bank-of-Z/logs/BANKZ-20260603.114759.608.tar'
   [INFO] [DBB-BUILD] Task: Finish
   [INFO] [DBB-BUILD] Build ended at 20260603.114916.574
   [INFO] [DBB-BUILD] Duration of build : 01 min, 16 sec
   [INFO] [DBB-BUILD] Total files processed : 72
   [INFO] [DBB-BUILD] Build Status : CLEAN
   [RESULT] [DBB-BUILD][BUILD-RESULT] /usr/local/sandboxes/bank-of-z/logs/dbb/BuildReport.json
   [RESULT] [DBB-BUILD][BUILD-LIST] /usr/local/sandboxes/bank-of-z/logs/dbb/buildList.txt
   [RESULT] [DBB-BUILD][TAR-PATH] /usr/local/sandboxes/bank-of-z/logs/dbb/BANKZ-20260603.114759.608.tar
   [RESULT] [DBB-BUILD][LOG-PATH] /usr/local/sandboxes/bank-of-z/logs/dbb/dbb-build-log.tar
   [SUCCESS] [DBB-BUILD] Process completed
   [SUCCESS] Bank of Z application build completed successfully

   =================================================================
   = STAGE 2: Deploy Bank of Z
   =================================================================

   [INFO] Running Bank of Z deploy script...
   [INFO] Executing: bash /usr/local/sandboxes/bank-of-z/Bank-of-Z/.setup/tasks/task-wazi-deploy.sh
   [INFO] [WAZIDEPLOY] Output directory  : /usr/local/sandboxes/bank-of-z/logs/deploy
   [INFO] [WAZIDEPLOY] Evidence directory: /usr/local/sandboxes/bank-of-z/logs/deploy/evidences
   [INFO] [WAZIDEPLOY] Copied types_pattern_mapping.yml to /usr/local/sandboxes/bank-of-z/dbb/WaziDeploy/zDeploy/deployment-configuration/global
   [INFO] [WAZIDEPLOY] =========================================
   [INFO] [WAZIDEPLOY] BankZ Deployment
   [INFO] [WAZIDEPLOY] =========================================
   [INFO] [WAZIDEPLOY] Starting wazideploy-generate for BankZ
   [INFO] [WAZIDEPLOY] Executing command:
   [INFO] [WAZIDEPLOY]     wazideploy-generate  --deploymentMethod /usr/local/sandboxes/bank-of-z/Bank-of-Z/.setup/deploy/deployment-method.yml  --deploymentPlan /usr/local/sandboxes/bank-of-z/logs/deploy/deploymentPlan-bankz.yaml  --deploymentPlanReport /usr/local/sandboxes/bank-of-z/logs/deploy/deploymentPlanReport-bankz.html  --packageInputFile /usr/local/sandboxes/bank-of-z/logs/dbb/BANKZ-20260603.114759.608.tar
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ * Read the deployment method from: /usr/local/sandboxes/bank-of-z/Bank-of-Z/.setup/deploy/deployment-method.yml
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ * Build the deployment plan from the deployment method
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ * Computing manifest version: None
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Generic step LOAD_CONFIG/READ_CONFIGURATION/INCLUDE_GLOBAL_CONFIG
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** No item found
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Generic step LOAD_CONFIG/READ_CONFIGURATION/INCLUDE_APPLICATION_VARIABLES
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** No item found
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Generic step LOAD_CONFIG/READ_CONFIGURATION/INCLUDE_MIDDLEWARE_CONFIG
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** No item found
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Generic step LOAD_CONFIG/READ_CONFIGURATION/INCLUDE_COMMON_CONFIG
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** No item found
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Generic step PACKAGE/EXPAND_PACKAGE/PACKAGE
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** No item found
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for CICS_REGION/CSD/UPDATE
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** No item found
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for DBRMS/DELETE/MEMBER_ARCHIVE
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** No item found
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for DBRMS/DELETE/MEMBER_DELETE
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** No item found
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for DBRMS/UPDATE/MEMBER_COPY
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** 12 items found [DELCUS.DBRM, UPDACC.DBRM, INQCUST.DBRM, INQACCCU.DBRM, CRECUST.DBRM, CREACC.DBRM, BANKDATA.DBRM, DBCRFUN.DBRM, DELACC.DBRM, XFRFUN.DBRM, INQACC.DBRM, UPDCUST.DBRM]
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for DBRMS/UPDATE/BIND_PACKAGE
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** 12 items found [DELCUS.DBRM, UPDACC.DBRM, INQCUST.DBRM, INQACCCU.DBRM, CRECUST.DBRM, CREACC.DBRM, BANKDATA.DBRM, DBCRFUN.DBRM, DELACC.DBRM, XFRFUN.DBRM, INQACC.DBRM, UPDCUST.DBRM]
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for DBRMS/UPDATE/BIND_PLAN
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** 12 items found [DELCUS.DBRM, UPDACC.DBRM, INQCUST.DBRM, INQACCCU.DBRM, CRECUST.DBRM, CREACC.DBRM, BANKDATA.DBRM, DBCRFUN.DBRM, DELACC.DBRM, XFRFUN.DBRM, INQACC.DBRM, UPDCUST.DBRM]
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for DEPLOY_MODULES/DELETE/MEMBER_ARCHIVE
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** No item found
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for DEPLOY_MODULES/DELETE/MEMBER_DELETE
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** No item found
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for DEPLOY_MODULES/UPDATE/MEMBER_ARCHIVE
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** 51 items found [BNK1ACC.MAPLOAD, BNK1CAM.MAPLOAD, BNK1DCM.MAPLOAD, BNK1DCS.CICSLOAD, UPDACC.CICSLOAD, BNK1MAI.MAPLOAD, BNK1CAC.CICSLOAD, BNK1DAC.CICSLOAD, INQACC.CICSLOAD, DELCUS.DBRM, XFRFUN.CICSLOAD, INQACCCU.CICSLOAD, INQCUST.CICSLOAD, BNK1CDM.MAPLOAD, UPDACC.DBRM, BNK1CCA.CICSLOAD, CRDTAGY4.CICSLOAD, UPDCUST.CICSLOAD, BNK1TFN.CICSLOAD, BNK1TFM.MAPLOAD, CREACC.CICSLOAD, BNK1CCS.CICSLOAD, GETCOMPY.CICSLOAD, ABNDPROC.CICSLOAD, BANKDATA.LOAD, CRECUST.CICSLOAD, DBCRFUN.CICSLOAD, INQCUST.DBRM, BNK1UAM.MAPLOAD, BNK1UAC.CICSLOAD, INQACCCU.DBRM, BNK1B2M.MAPLOAD, CRECUST.DBRM, GETSCODE.CICSLOAD, DELCUS.CICSLOAD, DELACC.CICSLOAD, BNKMENU.CICSLOAD, BNK1DAM.MAPLOAD, BNK1CRA.CICSLOAD, CREACC.DBRM, BANKDATA.DBRM, CRDTAGY5.CICSLOAD, CRDTAGY2.CICSLOAD, BNK1CCM.MAPLOAD, DBCRFUN.DBRM, CRDTAGY3.CICSLOAD, DELACC.DBRM, XFRFUN.DBRM, CRDTAGY1.CICSLOAD, INQACC.DBRM, UPDCUST.DBRM]
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for DEPLOY_MODULES/UPDATE/MEMBER_COPY
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** 51 items found [BNK1ACC.MAPLOAD, BNK1CAM.MAPLOAD, BNK1DCM.MAPLOAD, BNK1DCS.CICSLOAD, UPDACC.CICSLOAD, BNK1MAI.MAPLOAD, BNK1CAC.CICSLOAD, BNK1DAC.CICSLOAD, INQACC.CICSLOAD, DELCUS.DBRM, XFRFUN.CICSLOAD, INQACCCU.CICSLOAD, INQCUST.CICSLOAD, BNK1CDM.MAPLOAD, UPDACC.DBRM, BNK1CCA.CICSLOAD, CRDTAGY4.CICSLOAD, UPDCUST.CICSLOAD, BNK1TFN.CICSLOAD, BNK1TFM.MAPLOAD, CREACC.CICSLOAD, BNK1CCS.CICSLOAD, GETCOMPY.CICSLOAD, ABNDPROC.CICSLOAD, BANKDATA.LOAD, CRECUST.CICSLOAD, DBCRFUN.CICSLOAD, INQCUST.DBRM, BNK1UAM.MAPLOAD, BNK1UAC.CICSLOAD, INQACCCU.DBRM, BNK1B2M.MAPLOAD, CRECUST.DBRM, GETSCODE.CICSLOAD, DELCUS.CICSLOAD, DELACC.CICSLOAD, BNKMENU.CICSLOAD, BNK1DAM.MAPLOAD, BNK1CRA.CICSLOAD, CREACC.DBRM, BANKDATA.DBRM, CRDTAGY5.CICSLOAD, CRDTAGY2.CICSLOAD, BNK1CCM.MAPLOAD, DBCRFUN.DBRM, CRDTAGY3.CICSLOAD, DELACC.DBRM, XFRFUN.DBRM, CRDTAGY1.CICSLOAD, INQACC.DBRM, UPDCUST.DBRM]
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for ROLLBACK_MODULES/RESTORE/MEMBER_RESTORE
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** 51 items found [BNK1ACC.MAPLOAD, BNK1CAM.MAPLOAD, BNK1DCM.MAPLOAD, BNK1DCS.CICSLOAD, UPDACC.CICSLOAD, BNK1MAI.MAPLOAD, BNK1CAC.CICSLOAD, BNK1DAC.CICSLOAD, INQACC.CICSLOAD, DELCUS.DBRM, XFRFUN.CICSLOAD, INQACCCU.CICSLOAD, INQCUST.CICSLOAD, BNK1CDM.MAPLOAD, UPDACC.DBRM, BNK1CCA.CICSLOAD, CRDTAGY4.CICSLOAD, UPDCUST.CICSLOAD, BNK1TFN.CICSLOAD, BNK1TFM.MAPLOAD, CREACC.CICSLOAD, BNK1CCS.CICSLOAD, GETCOMPY.CICSLOAD, ABNDPROC.CICSLOAD, BANKDATA.LOAD, CRECUST.CICSLOAD, DBCRFUN.CICSLOAD, INQCUST.DBRM, BNK1UAM.MAPLOAD, BNK1UAC.CICSLOAD, INQACCCU.DBRM, BNK1B2M.MAPLOAD, CRECUST.DBRM, GETSCODE.CICSLOAD, DELCUS.CICSLOAD, DELACC.CICSLOAD, BNKMENU.CICSLOAD, BNK1DAM.MAPLOAD, BNK1CRA.CICSLOAD, CREACC.DBRM, BANKDATA.DBRM, CRDTAGY5.CICSLOAD, CRDTAGY2.CICSLOAD, BNK1CCM.MAPLOAD, DBCRFUN.DBRM, CRDTAGY3.CICSLOAD, DELACC.DBRM, XFRFUN.DBRM, CRDTAGY1.CICSLOAD, INQACC.DBRM, UPDCUST.DBRM]
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for ROLLBACK_MODULES/BIND/BIND_PACKAGE
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** 12 items found [DELCUS.DBRM, UPDACC.DBRM, INQCUST.DBRM, INQACCCU.DBRM, CRECUST.DBRM, CREACC.DBRM, BANKDATA.DBRM, DBCRFUN.DBRM, DELACC.DBRM, XFRFUN.DBRM, INQACC.DBRM, UPDCUST.DBRM]
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for ROLLBACK_MODULES/BIND/BIND_PLAN
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** 12 items found [DELCUS.DBRM, UPDACC.DBRM, INQCUST.DBRM, INQACCCU.DBRM, CRECUST.DBRM, CREACC.DBRM, BANKDATA.DBRM, DBCRFUN.DBRM, DELACC.DBRM, XFRFUN.DBRM, INQACC.DBRM, UPDCUST.DBRM]
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for VERIFICATION/JCLEXPERT/SCAN_JCL
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** No item found
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for CICS_ACTIVATION/UPDATE/PROG_UPDATE
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** 38 items found [BNK1ACC.MAPLOAD, BNK1CAM.MAPLOAD, BNK1DCM.MAPLOAD, BNK1DCS.CICSLOAD, UPDACC.CICSLOAD, BNK1MAI.MAPLOAD, BNK1CAC.CICSLOAD, BNK1DAC.CICSLOAD, INQACC.CICSLOAD, XFRFUN.CICSLOAD, INQACCCU.CICSLOAD, INQCUST.CICSLOAD, BNK1CDM.MAPLOAD, BNK1CCA.CICSLOAD, CRDTAGY4.CICSLOAD, UPDCUST.CICSLOAD, BNK1TFN.CICSLOAD, BNK1TFM.MAPLOAD, CREACC.CICSLOAD, BNK1CCS.CICSLOAD, GETCOMPY.CICSLOAD, ABNDPROC.CICSLOAD, CRECUST.CICSLOAD, DBCRFUN.CICSLOAD, BNK1UAM.MAPLOAD, BNK1UAC.CICSLOAD, BNK1B2M.MAPLOAD, GETSCODE.CICSLOAD, DELCUS.CICSLOAD, DELACC.CICSLOAD, BNKMENU.CICSLOAD, BNK1DAM.MAPLOAD, BNK1CRA.CICSLOAD, CRDTAGY5.CICSLOAD, CRDTAGY2.CICSLOAD, BNK1CCM.MAPLOAD, CRDTAGY3.CICSLOAD, CRDTAGY1.CICSLOAD]
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for Deploy WAR files/Copy to USS/USS_ARCHIVE
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** 2 items found [api.war, bank-frontend-vanilla.war]
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for Deploy WAR files/Copy to USS/USS_COPY
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** 2 items found [api.war, bank-frontend-vanilla.war]
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for Deploy WAR files/Copy to USS/USS_RESTORE
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** 2 items found [api.war, bank-frontend-vanilla.war]
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Collecting items for Deploy Config Files/Process Templates/TEMPLATE
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** 2 items found [api.war, bank-frontend-vanilla.war]
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Generic step Refresh z/OS Connect/SYSTEM_COMMAND/Refresh z/OS Config
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** No item found
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ ** Generic step Refresh z/OS Connect/SYSTEM_COMMAND/Refresh z/OS Applications
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ *** No item found
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ * Save the deployment plan to: /usr/local/sandboxes/bank-of-z/logs/deploy/deploymentPlan-bankz.yaml
   [INFO] [WAZIDEPLOY] [GENERATE-BANKZ * Save the deployment plan report to: /usr/local/sandboxes/bank-of-z/logs/deploy/deploymentPlanReport-bankz.html
   [INFO] [WAZIDEPLOY] Starting wazideploy-deploy for BankZ
   [INFO] [WAZIDEPLOY] Executing command:
   [INFO] [WAZIDEPLOY]     wazideploy-deploy  --workingFolder /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz  --deploymentPlan /usr/local/sandboxes/bank-of-z/logs/deploy/deploymentPlan-bankz.yaml  --envFile /usr/local/sandboxes/bank-of-z/Bank-of-Z/.setup/deploy/Development.yml  -e application=BANKZ  -e hlq=BANKZ.V0R1M0  -e deploy_cfg_home=/usr/local/sandboxes/bank-of-z/dbb/WaziDeploy/zDeploy  -e zos_connect_root=/usr/local/sandboxes/bank-of-z/zosconnect-server/servers/bankzServer    --packageInputFile /usr/local/sandboxes/bank-of-z/logs/dbb/BANKZ-20260603.114759.608.tar  --evidencesFileName /usr/local/sandboxes/bank-of-z/logs/deploy/evidences/evidence-bankz.yaml 
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Reading the deployment file from: /usr/local/sandboxes/bank-of-z/logs/deploy/deploymentPlan-bankz.yaml
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Reading the target environment file from: /usr/local/sandboxes/bank-of-z/Bank-of-Z/.setup/deploy/Development.yml
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Validate /usr/local/sandboxes/bank-of-z/logs/dbb/BANKZ-20260603.114759.608.tar fingerprint
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Checksum is valid for /usr/local/sandboxes/bank-of-z/logs/dbb/BANKZ-20260603.114759.608.tar
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Validate Deployment Plan before processing it
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** End of Deployment Plan validation
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Registering SMF Record
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing activity: LOAD_CONFIG(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing action: LOAD_CONFIG/READ_CONFIGURATION(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing step LOAD_CONFIG/READ_CONFIGURATION/INCLUDE_GLOBAL_CONFIG(s) with include_vars
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Read variable file /usr/local/sandboxes/bank-of-z/dbb/WaziDeploy/zDeploy/deployment-configuration/global/global_initialization.yml
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing step LOAD_CONFIG/READ_CONFIGURATION/INCLUDE_APPLICATION_VARIABLES(s) with include_vars
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Could not find or access file /usr/local/sandboxes/bank-of-z/dbb/WaziDeploy/zDeploy/environment-configuration/application-overrides/BANKZ/BankZ-Development.yml but ignored by files_must_exist=False
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing step LOAD_CONFIG/READ_CONFIGURATION/INCLUDE_MIDDLEWARE_CONFIG(s) with include_vars
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Read variable file /usr/local/sandboxes/bank-of-z/dbb/WaziDeploy/zDeploy/deployment-configuration/global/cics_config.yml
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Read variable file /usr/local/sandboxes/bank-of-z/dbb/WaziDeploy/zDeploy/deployment-configuration/global/db2_config.yml
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing step LOAD_CONFIG/READ_CONFIGURATION/INCLUDE_COMMON_CONFIG(s) with include_vars
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Read variable file /usr/local/sandboxes/bank-of-z/dbb/WaziDeploy/zDeploy/deployment-configuration/global/jcl_verification.yml
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Read variable file /usr/local/sandboxes/bank-of-z/dbb/WaziDeploy/zDeploy/deployment-configuration/global/pds_specification.yml
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Read variable file /usr/local/sandboxes/bank-of-z/dbb/WaziDeploy/zDeploy/deployment-configuration/global/types_pattern_mapping.yml
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing activity: PACKAGE(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing action: PACKAGE/EXPAND_PACKAGE(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing step PACKAGE/EXPAND_PACKAGE/PACKAGE(s) with package
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Processing package /usr/local/sandboxes/bank-of-z/logs/dbb/BANKZ-20260603.114759.608.tar
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Expand the package /usr/local/sandboxes/bank-of-z/logs/dbb/BANKZ-20260603.114759.608.tar to /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz on system os OS/390
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing activity: DBRMS(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing action: DBRMS/UPDATE(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing step DBRMS/UPDATE/MEMBER_COPY(s) with member_copy
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Create dataset BANKZ.V0R1M0.TMP.DBRM
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ***      {'space_primary': '10CYL', 'space_secondary': '20CYL', 'record_format': 'FB', 'record_length': 80, 'block_size': 32720, 'dataset_type': 'LIBRARY'}
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Copying 12 members to destination PDS BANKZ.V0R1M0.TMP.DBRM
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/DELCUS.DBRM to 'BANKZ.V0R1M0.TMP.DBRM(DELCUS)' (1/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/UPDACC.DBRM to 'BANKZ.V0R1M0.TMP.DBRM(UPDACC)' (2/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/INQCUST.DBRM to 'BANKZ.V0R1M0.TMP.DBRM(INQCUST)' (3/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/INQACCCU.DBRM to 'BANKZ.V0R1M0.TMP.DBRM(INQACCCU)' (4/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/CRECUST.DBRM to 'BANKZ.V0R1M0.TMP.DBRM(CRECUST)' (5/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/CREACC.DBRM to 'BANKZ.V0R1M0.TMP.DBRM(CREACC)' (6/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/BANKDATA.DBRM to 'BANKZ.V0R1M0.TMP.DBRM(BANKDATA)' (7/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/DBCRFUN.DBRM to 'BANKZ.V0R1M0.TMP.DBRM(DBCRFUN)' (8/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/DELACC.DBRM to 'BANKZ.V0R1M0.TMP.DBRM(DELACC)' (9/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/XFRFUN.DBRM to 'BANKZ.V0R1M0.TMP.DBRM(XFRFUN)' (10/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/INQACC.DBRM to 'BANKZ.V0R1M0.TMP.DBRM(INQACC)' (11/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/UPDCUST.DBRM to 'BANKZ.V0R1M0.TMP.DBRM(UPDCUST)' (12/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Copy to destination PDS BANKZ.V0R1M0.TMP.DBRM is done
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing step DBRMS/UPDATE/BIND_PACKAGE(s) with db2_bind_package
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform BIND PACKAGE on 'DELCUS.DBRM' (1/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform BIND PACKAGE on 'UPDACC.DBRM' (2/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform BIND PACKAGE on 'INQCUST.DBRM' (3/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform BIND PACKAGE on 'INQACCCU.DBRM' (4/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform BIND PACKAGE on 'CRECUST.DBRM' (5/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform BIND PACKAGE on 'CREACC.DBRM' (6/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform BIND PACKAGE on 'BANKDATA.DBRM' (7/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform BIND PACKAGE on 'DBCRFUN.DBRM' (8/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform BIND PACKAGE on 'DELACC.DBRM' (9/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform BIND PACKAGE on 'XFRFUN.DBRM' (10/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform BIND PACKAGE on 'INQACC.DBRM' (11/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform BIND PACKAGE on 'UPDCUST.DBRM' (12/12)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform BIND PACKAGE with template 'db2_bind_package.jcl.j2'
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Submit jcl /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/bind_package_1.jcl
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Job JOB00181 submitted with ZOAU Python API.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Job JOB00181 finished CC=0004
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing step DBRMS/UPDATE/BIND_PLAN(s) with db2_bind_plan
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform BIND PLAN with template 'db2_bind_plan.jcl.j2'
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Submit jcl /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/bind_plan_1.jcl
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Job JOB00182 submitted with ZOAU Python API.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Job JOB00182 finished CC=0000
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing activity: DEPLOY_MODULES(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing action: DEPLOY_MODULES/UPDATE(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing step DEPLOY_MODULES/UPDATE/MEMBER_ARCHIVE(s) with member_archive
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Create backup dataset BANKZ.V0R1M0.BACK.LOADLIB
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ***      {'space_primary': '10CYL', 'space_secondary': '20CYL', 'record_format': 'U', 'record_length': 0, 'block_size': 32760, 'dataset_type': 'LIBRARY'}
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Create backup dataset BANKZ.V0R1M0.BACK.DBRM
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ***      {'space_primary': '10CYL', 'space_secondary': '20CYL', 'record_format': 'FB', 'record_length': 80, 'block_size': 32720, 'dataset_type': 'LIBRARY'}
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Copying 12 members to destination PDS BANKZ.V0R1M0.BACK.DBRM
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.DBRM(DELCUS)' to 'BANKZ.V0R1M0.BACK.DBRM(DELCUS)' (1/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.DBRM(DELCUS)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.DBRM(UPDACC)' to 'BANKZ.V0R1M0.BACK.DBRM(UPDACC)' (2/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.DBRM(UPDACC)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.DBRM(INQCUST)' to 'BANKZ.V0R1M0.BACK.DBRM(INQCUST)' (3/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.DBRM(INQCUST)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.DBRM(INQACCCU)' to 'BANKZ.V0R1M0.BACK.DBRM(INQACCCU)' (4/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.DBRM(INQACCCU)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.DBRM(CRECUST)' to 'BANKZ.V0R1M0.BACK.DBRM(CRECUST)' (5/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.DBRM(CRECUST)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.DBRM(CREACC)' to 'BANKZ.V0R1M0.BACK.DBRM(CREACC)' (6/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.DBRM(CREACC)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.DBRM(BANKDATA)' to 'BANKZ.V0R1M0.BACK.DBRM(BANKDATA)' (7/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.DBRM(BANKDATA)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.DBRM(DBCRFUN)' to 'BANKZ.V0R1M0.BACK.DBRM(DBCRFUN)' (8/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.DBRM(DBCRFUN)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.DBRM(DELACC)' to 'BANKZ.V0R1M0.BACK.DBRM(DELACC)' (9/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.DBRM(DELACC)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.DBRM(XFRFUN)' to 'BANKZ.V0R1M0.BACK.DBRM(XFRFUN)' (10/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.DBRM(XFRFUN)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.DBRM(INQACC)' to 'BANKZ.V0R1M0.BACK.DBRM(INQACC)' (11/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.DBRM(INQACC)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.DBRM(UPDCUST)' to 'BANKZ.V0R1M0.BACK.DBRM(UPDCUST)' (12/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.DBRM(UPDCUST)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Archive to destination PDS BANKZ.V0R1M0.BACK.DBRM is done
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Copying 38 members to destination PDS BANKZ.V0R1M0.BACK.LOADLIB
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNK1ACC)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNK1ACC)' (13/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNK1ACC)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNK1CAM)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNK1CAM)' (14/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNK1CAM)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNK1DCM)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNK1DCM)' (15/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNK1DCM)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNK1MAI)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNK1MAI)' (16/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNK1MAI)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNK1CDM)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNK1CDM)' (17/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNK1CDM)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNK1TFM)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNK1TFM)' (18/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNK1TFM)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNK1UAM)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNK1UAM)' (19/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNK1UAM)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNK1DAM)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNK1DAM)' (20/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNK1DAM)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNK1CCM)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNK1CCM)' (21/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNK1CCM)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNK1DCS)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNK1DCS)' (22/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNK1DCS)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(UPDACC)' to 'BANKZ.V0R1M0.BACK.LOADLIB(UPDACC)' (23/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(UPDACC)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNK1CAC)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNK1CAC)' (24/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNK1CAC)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNK1DAC)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNK1DAC)' (25/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNK1DAC)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(INQACC)' to 'BANKZ.V0R1M0.BACK.LOADLIB(INQACC)' (26/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(INQACC)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(XFRFUN)' to 'BANKZ.V0R1M0.BACK.LOADLIB(XFRFUN)' (27/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(XFRFUN)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(INQACCCU)' to 'BANKZ.V0R1M0.BACK.LOADLIB(INQACCCU)' (28/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(INQACCCU)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(INQCUST)' to 'BANKZ.V0R1M0.BACK.LOADLIB(INQCUST)' (29/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(INQCUST)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNK1CCA)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNK1CCA)' (30/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNK1CCA)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(CRDTAGY4)' to 'BANKZ.V0R1M0.BACK.LOADLIB(CRDTAGY4)' (31/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(CRDTAGY4)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(UPDCUST)' to 'BANKZ.V0R1M0.BACK.LOADLIB(UPDCUST)' (32/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(UPDCUST)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNK1TFN)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNK1TFN)' (33/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNK1TFN)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(CREACC)' to 'BANKZ.V0R1M0.BACK.LOADLIB(CREACC)' (34/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(CREACC)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNK1CCS)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNK1CCS)' (35/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNK1CCS)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(GETCOMPY)' to 'BANKZ.V0R1M0.BACK.LOADLIB(GETCOMPY)' (36/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(GETCOMPY)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(ABNDPROC)' to 'BANKZ.V0R1M0.BACK.LOADLIB(ABNDPROC)' (37/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(ABNDPROC)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(CRECUST)' to 'BANKZ.V0R1M0.BACK.LOADLIB(CRECUST)' (38/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(CRECUST)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(DBCRFUN)' to 'BANKZ.V0R1M0.BACK.LOADLIB(DBCRFUN)' (39/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(DBCRFUN)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNK1UAC)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNK1UAC)' (40/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNK1UAC)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(GETSCODE)' to 'BANKZ.V0R1M0.BACK.LOADLIB(GETSCODE)' (41/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(GETSCODE)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(DELCUS)' to 'BANKZ.V0R1M0.BACK.LOADLIB(DELCUS)' (42/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(DELCUS)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(DELACC)' to 'BANKZ.V0R1M0.BACK.LOADLIB(DELACC)' (43/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(DELACC)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNKMENU)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNKMENU)' (44/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNKMENU)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BNK1CRA)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BNK1CRA)' (45/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BNK1CRA)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(CRDTAGY5)' to 'BANKZ.V0R1M0.BACK.LOADLIB(CRDTAGY5)' (46/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(CRDTAGY5)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(CRDTAGY2)' to 'BANKZ.V0R1M0.BACK.LOADLIB(CRDTAGY2)' (47/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(CRDTAGY2)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(CRDTAGY3)' to 'BANKZ.V0R1M0.BACK.LOADLIB(CRDTAGY3)' (48/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(CRDTAGY3)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(CRDTAGY1)' to 'BANKZ.V0R1M0.BACK.LOADLIB(CRDTAGY1)' (49/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(CRDTAGY1)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Archive 'BANKZ.V0R1M0.LOADLIB(BANKDATA)' to 'BANKZ.V0R1M0.BACK.LOADLIB(BANKDATA)' (50/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to archive 'BANKZ.V0R1M0.LOADLIB(BANKDATA)'. Member is absent.
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Archive to destination PDS BANKZ.V0R1M0.BACK.LOADLIB is done
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing step DEPLOY_MODULES/UPDATE/MEMBER_COPY(s) with member_copy
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Create dataset BANKZ.V0R1M0.DBRM
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ***      {'space_primary': '10CYL', 'space_secondary': '20CYL', 'record_format': 'FB', 'record_length': 80, 'block_size': 32720, 'dataset_type': 'LIBRARY'}
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Copying 12 members to destination PDS BANKZ.V0R1M0.DBRM
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/DELCUS.DBRM to 'BANKZ.V0R1M0.DBRM(DELCUS)' (1/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/UPDACC.DBRM to 'BANKZ.V0R1M0.DBRM(UPDACC)' (2/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/INQCUST.DBRM to 'BANKZ.V0R1M0.DBRM(INQCUST)' (3/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/INQACCCU.DBRM to 'BANKZ.V0R1M0.DBRM(INQACCCU)' (4/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/CRECUST.DBRM to 'BANKZ.V0R1M0.DBRM(CRECUST)' (5/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/CREACC.DBRM to 'BANKZ.V0R1M0.DBRM(CREACC)' (6/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/BANKDATA.DBRM to 'BANKZ.V0R1M0.DBRM(BANKDATA)' (7/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/DBCRFUN.DBRM to 'BANKZ.V0R1M0.DBRM(DBCRFUN)' (8/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/DELACC.DBRM to 'BANKZ.V0R1M0.DBRM(DELACC)' (9/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/XFRFUN.DBRM to 'BANKZ.V0R1M0.DBRM(XFRFUN)' (10/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/INQACC.DBRM to 'BANKZ.V0R1M0.DBRM(INQACC)' (11/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/dbrm/UPDCUST.DBRM to 'BANKZ.V0R1M0.DBRM(UPDCUST)' (12/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Copy to destination PDS BANKZ.V0R1M0.DBRM is done
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Copying 38 members to destination PDS BANKZ.V0R1M0.LOADLIB
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/mapload/BNK1ACC.MAPLOAD to 'BANKZ.V0R1M0.LOADLIB(BNK1ACC)' (13/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/mapload/BNK1CAM.MAPLOAD to 'BANKZ.V0R1M0.LOADLIB(BNK1CAM)' (14/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/mapload/BNK1DCM.MAPLOAD to 'BANKZ.V0R1M0.LOADLIB(BNK1DCM)' (15/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/mapload/BNK1MAI.MAPLOAD to 'BANKZ.V0R1M0.LOADLIB(BNK1MAI)' (16/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/mapload/BNK1CDM.MAPLOAD to 'BANKZ.V0R1M0.LOADLIB(BNK1CDM)' (17/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/mapload/BNK1TFM.MAPLOAD to 'BANKZ.V0R1M0.LOADLIB(BNK1TFM)' (18/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/mapload/BNK1UAM.MAPLOAD to 'BANKZ.V0R1M0.LOADLIB(BNK1UAM)' (19/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/mapload/BNK1DAM.MAPLOAD to 'BANKZ.V0R1M0.LOADLIB(BNK1DAM)' (20/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/mapload/BNK1CCM.MAPLOAD to 'BANKZ.V0R1M0.LOADLIB(BNK1CCM)' (21/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/BNK1DCS.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(BNK1DCS)' (22/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/UPDACC.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(UPDACC)' (23/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/BNK1CAC.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(BNK1CAC)' (24/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/BNK1DAC.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(BNK1DAC)' (25/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/INQACC.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(INQACC)' (26/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/XFRFUN.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(XFRFUN)' (27/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/INQACCCU.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(INQACCCU)' (28/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/INQCUST.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(INQCUST)' (29/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/BNK1CCA.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(BNK1CCA)' (30/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/CRDTAGY4.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(CRDTAGY4)' (31/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/UPDCUST.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(UPDCUST)' (32/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/BNK1TFN.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(BNK1TFN)' (33/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/CREACC.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(CREACC)' (34/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/BNK1CCS.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(BNK1CCS)' (35/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/GETCOMPY.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(GETCOMPY)' (36/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/ABNDPROC.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(ABNDPROC)' (37/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/CRECUST.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(CRECUST)' (38/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/DBCRFUN.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(DBCRFUN)' (39/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/BNK1UAC.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(BNK1UAC)' (40/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/GETSCODE.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(GETSCODE)' (41/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/DELCUS.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(DELCUS)' (42/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/DELACC.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(DELACC)' (43/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/BNKMENU.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(BNKMENU)' (44/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/BNK1CRA.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(BNK1CRA)' (45/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/CRDTAGY5.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(CRDTAGY5)' (46/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/CRDTAGY2.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(CRDTAGY2)' (47/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/CRDTAGY3.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(CRDTAGY3)' (48/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/cicsload/CRDTAGY1.CICSLOAD to 'BANKZ.V0R1M0.LOADLIB(CRDTAGY1)' (49/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./bin/load/BANKDATA.LOAD to 'BANKZ.V0R1M0.LOADLIB(BANKDATA)' (50/50)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Copy to destination PDS BANKZ.V0R1M0.LOADLIB is done
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing activity: ROLLBACK_MODULES(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing action: ROLLBACK_MODULES/RESTORE(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *? WARNING: Step MEMBER_RESTORE skipped due to a tag
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing action: ROLLBACK_MODULES/BIND(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *? WARNING: Step BIND_PACKAGE skipped due to a tag
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *? WARNING: Step BIND_PLAN skipped due to a tag
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing activity: CICS_ACTIVATION(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing action: CICS_ACTIVATION/UPDATE(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing step CICS_ACTIVATION/UPDATE/PROG_UPDATE(s) with cics_cmci_prog_update
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNK1ACC on 'CICSBOZ' (1/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNK1CAM on 'CICSBOZ' (2/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNK1DCM on 'CICSBOZ' (3/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNK1MAI on 'CICSBOZ' (4/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNK1CDM on 'CICSBOZ' (5/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNK1TFM on 'CICSBOZ' (6/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNK1UAM on 'CICSBOZ' (7/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNK1DAM on 'CICSBOZ' (8/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNK1CCM on 'CICSBOZ' (9/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNK1DCS on 'CICSBOZ' (10/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on UPDACC on 'CICSBOZ' (11/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNK1CAC on 'CICSBOZ' (12/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNK1DAC on 'CICSBOZ' (13/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on INQACC on 'CICSBOZ' (14/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on XFRFUN on 'CICSBOZ' (15/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on INQACCCU on 'CICSBOZ' (16/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on INQCUST on 'CICSBOZ' (17/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNK1CCA on 'CICSBOZ' (18/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on CRDTAGY4 on 'CICSBOZ' (19/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on UPDCUST on 'CICSBOZ' (20/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNK1TFN on 'CICSBOZ' (21/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on CREACC on 'CICSBOZ' (22/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNK1CCS on 'CICSBOZ' (23/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on GETCOMPY on 'CICSBOZ' (24/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on ABNDPROC on 'CICSBOZ' (25/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on CRECUST on 'CICSBOZ' (26/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on DBCRFUN on 'CICSBOZ' (27/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNK1UAC on 'CICSBOZ' (28/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on GETSCODE on 'CICSBOZ' (29/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on DELCUS on 'CICSBOZ' (30/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on DELACC on 'CICSBOZ' (31/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNKMENU on 'CICSBOZ' (32/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on BNK1CRA on 'CICSBOZ' (33/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on CRDTAGY5 on 'CICSBOZ' (34/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on CRDTAGY2 on 'CICSBOZ' (35/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on CRDTAGY3 on 'CICSBOZ' (36/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Perform CICS NEWCOPY on CRDTAGY1 on 'CICSBOZ' (37/37)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing activity: Deploy WAR files(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing action: Deploy WAR files/Copy to USS(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing step Deploy WAR files/Copy to USS/USS_ARCHIVE(s) with uss_archive
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Copy /usr/local/sandboxes/bank-of-z/zosconnect-server/servers/bankzServer/apps/api.war to /usr/local/sandboxes/bank-of-z/zosconnect-server/servers/bankzServer/backup/apps/api.war
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to copy '/usr/local/sandboxes/bank-of-z/zosconnect-server/servers/bankzServer/apps/api.war' to '/usr/local/sandboxes/bank-of-z/zosconnect-server/servers/bankzServer/backup/apps/api.war' - '/usr/local/sandboxes/bank-of-z/zosconnect-server/servers/bankzServer/apps/api.war' does not exist
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Copy /usr/local/sandboxes/bank-of-z/zosconnect-server/servers/bankzServer/apps/bank-frontend-vanilla.war to /usr/local/sandboxes/bank-of-z/zosconnect-server/servers/bankzServer/backup/apps/bank-frontend-vanilla.war
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] **** Skipped to copy '/usr/local/sandboxes/bank-of-z/zosconnect-server/servers/bankzServer/apps/bank-frontend-vanilla.war' to '/usr/local/sandboxes/bank-of-z/zosconnect-server/servers/bankzServer/backup/apps/bank-frontend-vanilla.war' - '/usr/local/sandboxes/bank-of-z/zosconnect-server/servers/bankzServer/apps/bank-frontend-vanilla.war' does not exist
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing step Deploy WAR files/Copy to USS/USS_COPY(s) with uss_copy
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./uss/zcee3/api.war to /usr/local/sandboxes/bank-of-z/zosconnect-server/servers/bankzServer/apps/api.war
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Copy /usr/local/sandboxes/bank-of-z/logs/deploy/work-bankz/./uss/war/bank-frontend-vanilla.war to /usr/local/sandboxes/bank-of-z/zosconnect-server/servers/bankzServer/apps/bank-frontend-vanilla.war
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *? WARNING: Step USS_RESTORE skipped due to a tag
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing activity: Deploy Config Files(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing action: Deploy Config Files/Process Templates(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing step Deploy Config Files/Process Templates/TEMPLATE(s) with template
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Render template /usr/local/sandboxes/bank-of-z/Bank-of-Z/.setup/deploy/zos_connect_app_config.xml.j2 to '/usr/local/sandboxes/bank-of-z/zosconnect-server/servers/bankzServer/configDropins/overrides/api.xml'
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** Render template /usr/local/sandboxes/bank-of-z/Bank-of-Z/.setup/deploy/zos_connect_app_config.xml.j2 to '/usr/local/sandboxes/bank-of-z/zosconnect-server/servers/bankzServer/configDropins/overrides/bank-frontend-vanilla.xml'
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing activity: Refresh z/OS Connect(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing action: Refresh z/OS Connect/SYSTEM_COMMAND(s)
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing step Refresh z/OS Connect/SYSTEM_COMMAND/Refresh z/OS Config(s) with system_command
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** System command
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Processing step Refresh z/OS Connect/SYSTEM_COMMAND/Refresh z/OS Applications(s) with system_command
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] *** System command
   [INFO] [WAZIDEPLOY] [DEPLOY-BANKZ] ** Evidences saved in /usr/local/sandboxes/bank-of-z/logs/deploy/evidences/evidence-bankz.yaml
   [SUCCESS] [WAZIDEPLOY] deployment completed successfully
   [SUCCESS] [WAZIDEPLOY] BankZ deployment completed successfully
   [INFO] [WAZIDEPLOY] Cleaning up package file
   [SUCCESS] [WAZIDEPLOY] Wazi Deploy process completed successfully
   [RESULT] [WAZIDEPLOY][LOG-PATH] /usr/local/sandboxes/bank-of-z/logs/deploy/wazi-deploy-log.tar
   [SUCCESS] [DBB-BUILD] Process completed
   [SUCCESS] Bank of Z application deploy completed successfully

   =================================================================
   = STAGE 3: Populate DB2 database
   =================================================================

   [INFO] Running Bank of Z database populate script...
   [INFO] Executing: bash /usr/local/sandboxes/bank-of-z/Bank-of-Z/.setup/setup/populate-db2-tables.sh
   ==> Submitting /tmp/Db2-bind.jcl.83887505 via jsub...
   JOB00183
   Waiting for job JOB00183...
   IBMUSER  DB2BIND  JOB00183 CC        0000 
   IBMUSER  DB2BIND  JOB00183 CC        0000 
   ===== JESYSMSG =====
   ICH70001I IBMUSER  LAST ACCESS AT 11:49:33 ON WEDNESDAY, JUNE 3, 2026
   IEFA111I DB2BIND IS USING THE FOLLOWING JOB RELATED SETTINGS:
            SWA=BELOW,TIOT SIZE=64K,DSENQSHR=DISALLOW,GDGBIAS=JOB
   IEF236I ALLOC. FOR DB2BIND BIND
   IGD103I SMS ALLOCATED TO DDNAME STEPLIB
   IGD103I SMS ALLOCATED TO DDNAME
   IGD103I SMS ALLOCATED TO DDNAME DBRMLIB
   IGD103I SMS ALLOCATED TO DDNAME
   IGD103I SMS ALLOCATED TO DDNAME
   IGD103I SMS ALLOCATED TO DDNAME
   IGD103I SMS ALLOCATED TO DDNAME
   IGD103I SMS ALLOCATED TO DDNAME
   IGD103I SMS ALLOCATED TO DDNAME
   IGD103I SMS ALLOCATED TO DDNAME
   IGD103I SMS ALLOCATED TO DDNAME
   IGD103I SMS ALLOCATED TO DDNAME
   IGD103I SMS ALLOCATED TO DDNAME
   IGD103I SMS ALLOCATED TO DDNAME
   IEF237I JES2 ALLOCATED TO SYSPRINT
   IEF237I JES2 ALLOCATED TO SYSTSPRT
   IEF237I JES2 ALLOCATED TO SYSUDUMP
   IEF237I JES2 ALLOCATED TO SYSTSIN
   IEF142I DB2BIND BIND - STEP WAS EXECUTED - COND CODE 0000
   IGD104I DB2V13.SDSNEXIT                              RETAINED,  DDNAME=STEPLIB 
   IGD104I DB2V13.SDSNLOAD                              RETAINED,  DDNAME=        
   IEF285I   IBMUSER.DB2BIND.JOB00183.D0000104.?          SYSOUT        
   IEF285I   IBMUSER.DB2BIND.JOB00183.D0000105.?          SYSOUT        
   IEF285I   IBMUSER.DB2BIND.JOB00183.D0000106.?          SYSOUT        
   IEF285I   IBMUSER.DB2BIND.JOB00183.D0000101.?          SYSIN         
   IGD104I BANKZ.V0R1M0.DBRM                            RETAINED,  DDNAME=DBRMLIB 
   IGD104I BANKZ.V0R1M0.DBRM                            RETAINED,  DDNAME=        
   IGD104I BANKZ.V0R1M0.DBRM                            RETAINED,  DDNAME=        
   IGD104I BANKZ.V0R1M0.DBRM                            RETAINED,  DDNAME=        
   IGD104I BANKZ.V0R1M0.DBRM                            RETAINED,  DDNAME=        
   IGD104I BANKZ.V0R1M0.DBRM                            RETAINED,  DDNAME=        
   IGD104I BANKZ.V0R1M0.DBRM                            RETAINED,  DDNAME=        
   IGD104I BANKZ.V0R1M0.DBRM                            RETAINED,  DDNAME=        
   IGD104I BANKZ.V0R1M0.DBRM                            RETAINED,  DDNAME=        
   IGD104I BANKZ.V0R1M0.DBRM                            RETAINED,  DDNAME=        
   IGD104I BANKZ.V0R1M0.DBRM                            RETAINED,  DDNAME=        
   IGD104I BANKZ.V0R1M0.DBRM                            RETAINED,  DDNAME=        
   IEF373I STEP/BIND    /START 2026154.1149
   IEF032I STEP/BIND    /STOP  2026154.1149 
            CPU:     0 HR  00 MIN  00.09 SEC    SRB:     0 HR  00 MIN  00.00 SEC    
            VIRT:   512K  SYS:   464K  EXT:      496K  SYS:    10692K
            ATB- REAL:                   228K  SLOTS:                     0K
               VIRT- ALLOC:      13M SHRD:       0M
   IEF236I ALLOC. FOR DB2BIND GRANT
   IGD103I SMS ALLOCATED TO DDNAME STEPLIB
   IGD103I SMS ALLOCATED TO DDNAME
   IEF237I JES2 ALLOCATED TO SYSUDUMP
   IEF237I JES2 ALLOCATED TO SYSPRINT
   IEF237I JES2 ALLOCATED TO SYSTSPRT
   IEF237I JES2 ALLOCATED TO SYSTSIN
   IEF237I JES2 ALLOCATED TO SYSIN
   IGD103I SMS ALLOCATED TO DDNAME SYS00001
   IGD104I DBD1.RUNLIB.LOAD                             RETAINED,  DDNAME=SYS00001
   IEF142I DB2BIND GRANT - STEP WAS EXECUTED - COND CODE 0000
   IGD104I DB2V13.SDSNEXIT                              RETAINED,  DDNAME=STEPLIB 
   IGD104I DB2V13.SDSNLOAD                              RETAINED,  DDNAME=        
   IEF285I   IBMUSER.DB2BIND.JOB00183.D0000107.?          SYSOUT        
   IEF285I   IBMUSER.DB2BIND.JOB00183.D0000108.?          SYSOUT        
   IEF285I   IBMUSER.DB2BIND.JOB00183.D0000109.?          SYSOUT        
   IEF285I   IBMUSER.DB2BIND.JOB00183.D0000102.?          SYSIN         
   IEF285I   IBMUSER.DB2BIND.JOB00183.D0000103.?          SYSIN         
   IEF373I STEP/GRANT   /START 2026154.1149
   IEF032I STEP/GRANT   /STOP  2026154.1149 
            CPU:     0 HR  00 MIN  00.01 SEC    SRB:     0 HR  00 MIN  00.00 SEC    
            VIRT:   568K  SYS:   424K  EXT:     6108K  SYS:    10696K
            ATB- REAL:                   228K  SLOTS:                     0K
               VIRT- ALLOC:      13M SHRD:       0M
   IEF375I  JOB/DB2BIND /START 2026154.1149
   IEF033I  JOB/DB2BIND /STOP  2026154.1149 
            CPU:     0 HR  00 MIN  00.10 SEC    SRB:     0 HR  00 MIN  00.00 SEC    
   ==> Submitting /tmp/Db2-insert.jcl.83887505 via jsub...
   JOB00184
   Waiting for job JOB00184...
   IBMUSER  DB2INSRT JOB00184 AC           ? 
   IBMUSER  DB2INSRT JOB00184 AC           ? 
   IBMUSER  DB2INSRT JOB00184 CC        0000 
   IBMUSER  DB2INSRT JOB00184 CC        0000 
   ===== JESYSMSG =====
   ICH70001I IBMUSER  LAST ACCESS AT 11:49:53 ON WEDNESDAY, JUNE 3, 2026
   IEFA111I DB2INSRT IS USING THE FOLLOWING JOB RELATED SETTINGS:
            SWA=BELOW,TIOT SIZE=64K,DSENQSHR=DISALLOW,GDGBIAS=JOB
   IEF236I ALLOC. FOR DB2INSRT GRANT
   IGD103I SMS ALLOCATED TO DDNAME JOBLIB
   IEF237I JES2 ALLOCATED TO SYSTSPRT
   IEF237I JES2 ALLOCATED TO SYSPRINT
   IEF237I JES2 ALLOCATED TO SYSUDUMP
   IEF237I JES2 ALLOCATED TO SYSTSIN
   IGD103I SMS ALLOCATED TO DDNAME SYS00001
   IGD104I BANKZ.V0R1M0.LOADLIB                         RETAINED,  DDNAME=SYS00001
   IEF142I DB2INSRT GRANT - STEP WAS EXECUTED - COND CODE 0000
   IEF285I   IBMUSER.DB2INSRT.JOB00184.D0000102.?         SYSOUT        
   IEF285I   IBMUSER.DB2INSRT.JOB00184.D0000103.?         SYSOUT        
   IEF285I   IBMUSER.DB2INSRT.JOB00184.D0000104.?         SYSOUT        
   IEF285I   IBMUSER.DB2INSRT.JOB00184.D0000101.?         SYSIN         
   IEF373I STEP/GRANT   /START 2026154.1149
   IEF032I STEP/GRANT   /STOP  2026154.1149 
            CPU:     0 HR  00 MIN  00.97 SEC    SRB:     0 HR  00 MIN  00.00 SEC    
            VIRT:   520K  SYS:   412K  EXT:     3900K  SYS:    10616K
            ATB- REAL:                   228K  SLOTS:                     0K
               VIRT- ALLOC:      13M SHRD:       0M
   IGD104I DB2V13.SDSNLOAD                              RETAINED,  DDNAME=JOBLIB  
   IEF375I  JOB/DB2INSRT/START 2026154.1149
   IEF033I  JOB/DB2INSRT/STOP  2026154.1149 
            CPU:     0 HR  00 MIN  00.97 SEC    SRB:     0 HR  00 MIN  00.00 SEC    
   [SUCCESS] Bank of Z application populate completed successfully
   ```
   </details>
1. Open the application fronted
   Here you should see the Bank of Z fronted:
   - http://x.x.x.x:9080/bank-frontend-vanilla
   - Where x.x.x.x is the ip/hostname of your z/OS.

### Option 1: GRUB Workflow (Recommended for Active Development)

**Best for**: Rapid iteration with uncommitted changes

1. Make changes locally
2. Run GRUB to sync and setup

GRUB automatically syncs your changes to USS and executes [`setup-remote.sh`](../.setup/setup-remote.sh) there.

📖 [Detailed GRUB Guide →](WORKFLOW-GRUB.md)

### Option 2: VSCode Task Workflow

**Best for**: Branch-based development with version control

1. Commit and push changes
git add .
git commit -m "Update menu logic"
git push

2. Run VSCode task
Press: Ctrl+Shift+P (or Cmd+Shift+P on Mac)
Select: "Tasks: Run Task"
Choose: "Setup Bank of Z Environment"

The task runs [`setup-local.sh`](../.setup/setup-local.sh) which orchestrates the remote setup via Zowe CLI.

📖 [Detailed VSCode Guide →](WORKFLOW-VSCODE.md)

## ⚙️ Configuration

Before running setup, edit [`../.setup/config/config.yaml`](../.setup/config/config.yaml):

```yaml
# Workspace location on z/OS USS
sandbox:
  path: /usr/local/sandboxes/bank-of-z

# Application identity
app:
  base_name: BANKZ    # Dataset prefix (max 8 chars)
  short_name: BOZ     # Short identifier (max 4 chars)
  zos_version: V0R1M0 # Version for dataset naming

# DBB configuration
dbb:
  dbb_home: /usr/lpp/IBM/dbb
  java_home: /usr/lpp/java/java21/current_64
```

📖 [Full Configuration Guide →](CONFIGURATION.md)

## 📁 Scripts

### Setup Scripts

#### [`setup-common.sh`](../.setup/setup-common.sh)
**Purpose**: Main setup script that runs natively on z/OS USS

**Used by**: Both GRUB and VSCode workflows

**What it does**:
1. Initializes workspace directory
2. Clones DBB accelerators repository
3. Deploys zBuilder framework
4. Installs Bank of Z application

**Execution**: Native USS commands (no Zowe CLI needed)

#### [`setup-local.sh`](../.setup/setup-local.sh)
**Purpose**: Local orchestrator for VSCode task workflow

**Used by**: VSCode tasks only

**What it does**:
1. Creates workspace on remote USS (via Zowe CLI)
2. Clones Bank of Z branch on remote
3. Executes [`setup-common.sh`](../.setup/setup-common.sh) on remote

**Execution**: Runs locally, uses Zowe CLI for remote operations

### Pipeline Scripts

#### [`pipeline-remote.sh`](../.setup/pipeline-remote.sh)
**Purpose**: Pipeline simulation script that runs natively on z/OS USS

**Used by**: Both GRUB and VSCode workflows

**What it does**:
1. Refreshes git repository (VSCode workflow only)
2. Runs DBB build
3. Deploys to CICS

**Execution**: Native USS commands (no Zowe CLI needed)

#### [`pipeline-local.sh`](../.setup/pipeline-local.sh)
**Purpose**: Local orchestrator for pipeline execution

**Used by**: VSCode tasks only

**What it does**:
1. Uploads pipeline script to USS (via Zowe CLI)
2. Uploads deploy configurations
3. Executes [`setup-common.sh`](../.setup/setup-common.sh) on remote

**Execution**: Runs locally, uses Zowe CLI for remote operations

## 📂 What Gets Created

After successful setup:

```
/usr/local/sandboxes/bank-of-z/  (your configured path)
├── dbb/                          # DBB accelerators from GitHub
│   ├── Pipeline/
│   ├── Build/
│   └── ...
├── zBuilder/                     # Build framework
│   ├── languages/
│   ├── datasets.yaml
│   └── ...
└── Bank-of-Z/                    # Application source
    ├── src/                      # COBOL, BMS, copybooks
    │   ├── base/
    │   ├── api/
    │   └── frontend/
    ├── .setup/                   # Setup scripts
    └── dbb-app.yaml              # DBB configuration
```

## 🔧 Troubleshooting

### Common Issues

#### "Zowe CLI not found" (VSCode workflow only)
```bash
# Install Zowe CLI
npm install -g @zowe/cli

# Install RSE API plugin
zowe plugins install @zowe/rse-api-for-zowe-cli

# Verify installation
zowe --version
```

#### "Git not available on remote"
- Ensure git is installed on z/OS USS
- Check that git is in the PATH
- Test via SSH: `git --version`

#### "Permission denied" errors
- Verify write access to sandbox path in [`config.yaml`](.setup/config/config.yaml:1)
- Check directory ownership: `ls -la /usr/local/sandboxes/`
- Ensure your user has appropriate USS permissions

#### "Directory already exists" prompts
- Answer `y` to delete and recreate (fresh start)
- Answer `n` to keep existing (skip that stage)

#### Setup fails during Bank of Z installation
- Check `/tmp/build.log` for detailed error messages
- Verify CICS region is available
- Ensure required datasets are accessible

📖 [More Troubleshooting →](docs/TROUBLESHOOTING.md)

## 📚 Additional Documentation

- [GRUB Workflow Guide](docs/WORKFLOW-GRUB.md) - Detailed GRUB setup and usage
- [VSCode Task Workflow Guide](docs/WORKFLOW-VSCODE.md) - VSCode task configuration
- [Configuration Reference](docs/CONFIGURATION.md) - Complete config.yaml guide
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md) - Common issues and solutions

## 🔄 Workflow Comparison

| Feature | GRUB Workflow | VSCode Task Workflow |
|---------|---------------|---------------------|
| **Speed** | ⚡ Fast (patch-based sync) | 🐢 Slower (full clone) |
| **Requires commit** | ❌ No | ✅ Yes |
| **Works with uncommitted changes** | ✅ Yes | ❌ No |
| **Requires Zowe CLI** | ❌ No | ✅ Yes |
| **Requires SSH access** | ✅ Yes | ❌ No |
| **Best for** | Active development | Branch-based workflow |

## 📝 Next Steps After Setup

### 1. Verify Bank of Z Installation

Connect to CICS using x3270 emulator:

```
logon applid(CICSBOZ)
```

Then test the application:
- Transaction: `OMEN`
- Customer ID: `1`
- Account: `1234`

## 📄 License

This project is part of the Bank of Z application. See the main project LICENSE file.

---

**Made with Bob** 🤖