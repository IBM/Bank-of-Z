---
layout: default
title: Set Up a Database Connection to Db2 for z/OS
---

# Set Up a Database Connection to Db2 for z/OS

Establish a JDBC connection from VS Code or Bob to Db2 for z/OS by using the Db2 for z/OS Developer Extension.

## Prerequisites

- Complete the [IDE Setup](https://ibm.github.io/Bank-of-Z/docs/installation-and-setup/local-tools/ide-setup.html)⁠ steps
- Configure the JDBC driver and license files as described in the **Setting the JDBC license** and **JDBC driver files** guide
- Access to the Bank of Z z/OS environment

## Step 1: Gather Db2 runtime information

Identify the Db2 location name and port by running the following commands from a USS terminal session.

Create the JCL file:

```bash
cat > "/tmp/db2-info.jcl" <<EOF
//DB2INFO JOB CLASS=A,MSGCLASS=A
//PRINTLOG EXEC PGM=DSNJU004
//STEPLIB  DD DISP=SHR,DSN=DB2V13.SDSNLOAD
//SYSUT1   DD DISP=SHR,DSN=DBD1.BSDS01
//SYSPRINT DD SYSOUT=*
/*
EOF
```

Submit the job and capture the job ID:

```bash
JOBID=$(jsub -f "/tmp/db2-info.jcl")
```

Extract the LOCATION information from the job output:

```bash
pjdd "$JOBID" "*" | grep LOCATION
```

For example:

```bash
-LOCATION=DBD1LOC IPNAME=(NULL) PORT=8102 SPORT=8102 RPORT=8101
```

**Note**: The ```LOCATION``` value, such as ```DBD1LOC```, and the ```PORT``` value, such as ```8102```. You use these values when configuring the Db2 connection.

## Step 2: Retrieve the security certificate

### 2a. Export the CA certificate from RACF

From a USS terminal session, run:

```bash
tsocmd "RACDCERT CERTAUTH EXPORT(LABEL('VSICA')) DSN('IBMUSER.VSICA.CER') FORMAT(CERTDER)"
```

### 2b. Download the certificate to your local workstation

From a terminal on your local workstation, run:

```bash
zowe rse download ds "IBMUSER.VSICA.CER" -b -f "vsica.txt"
```

### 2c. Create a local truststore

Use the Java ```keytool``` utility to import the certificate into a new truststore. Adjust the alias, input file name, and truststore name as needed.

```bash
keytool -importcert \
  -alias vsica \
  -file vsica.txt \
  -keystore db2-truststore.jks \
  -storepass db2trust \
  -noprompt
```

The ```-storepass``` value, ```db2trust``` in this example, becomes the ```sslTrustStorePassword``` value that you use when configuring the connection.

## Step 3: Configure the Db2 connection

Open the **Db2 for z/OS Developer Extension** in VS Code or Bob and create a new connection.

Make sure that you have configured the JDBC driver and license files according to the **Setting the JDBC license and JDBC driver files** guide.

### 3a. Basic connection settings

Enter the following connection information:

| Field | Value |
|----------|-----------------|
| Location name | ```DBD1LOC``` or the ```LOCATION``` value from Step 1 |
| Hostname | ```<your-mainframe-hostname>``` |
| Port | ```8102``` or the ```PORT``` value from Step 1 |

### 3b. SSL settings

Under the Optional tab, configure the following JDBC properties:

| Property | Value |
|----------|-----------------|
| ```sslConnection``` | ```true``` |
| ```sslTrustStoreLocation``` | Full path to ```db2-truststore.jks``` created in Step 2 |
| ```sslTrustStorePassword``` | Truststore password set in Step 2c |
| ```sslVersion``` | ```TLSv1.2``` |

## Result

You can now establish a JDBC connection to Db2 for z/OS from VS Code or Bob by using the Db2 for z/OS Developer Extension.


