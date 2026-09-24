# Set Up a Database Connection via the Db2 for z/OS Developer Extension

Establish a JDBC connection from your IDE (VS Code or Bob) to Db2 for z/OS.

## Prerequisites

- Completed IDE setup steps as outlined in [IDE Setup](../installation-and-setup/local-tools/ide-setup.html).

---

## Step 1 — Gather Db2 Runtime Information

Identify the Db2 port and location name by running the following commands from a USS terminal session.

**Store job under USS:**

Run from a USS terminal session 

```sh
cat > "/tmp/db2-info.jcl" <<EOF
//DB2INFO JOB CLASS=A,MSGCLASS=A
//PRINTLOG EXEC PGM=DSNJU004
//STEPLIB  DD DISP=SHR,DSN=DB2V13.SDSNLOAD
//SYSUT1   DD DISP=SHR,DSN=DBD1.BSDS01
//SYSPRINT DD SYSOUT=*
/*
EOF
```

Submit and capture the job ID:

```sh
JOBID=$(jsub -f "/tmp/db2-info.jcl")
```

Extract the LOCATION line from the job output:

```sh
pjdd "$JOBID" "*" | grep LOCATION
```

Sample output:

```
-LOCATION=DBD1LOC IPNAME=(NULL) PORT=8102 SPORT=8102 RPORT=8101
```

Note the `LOCATION` name (e.g. `DBD1LOC`) and the `PORT` value (e.g. `8102`) — you will need them when configuring the connection in Step 3.

---

## Step 2 — Retrieve the Security Certificate

### 2a. Export the CA certificate from RACF

From a USS terminal session, run:

```sh
tsocmd "RACDCERT CERTAUTH EXPORT(LABEL('VSICA')) DSN('IBMUSER.VSICA.CER') FORMAT(CERTDER)"
```

### 2b. Download the certificate to your local workstation

Open a terminal on your local machine and run:

```sh
zowe rse download ds "IBMUSER.VSICA.CER" -b -f "vsica.txt"
```

### 2c. Create a local truststore

Use the Java `keytool` utility to import the certificate into a new truststore. Adjust the alias, input file name, and truststore name as needed.

```sh
keytool -importcert \
  -alias vsica \
  -file vsica.txt \
  -keystore db2-truststore.jks \
  -storepass db2trust \
  -noprompt
```

> **Note:** The `-storepass` value (`db2trust` above) becomes your `sslTrustStorePassword`. Keep it for use in Step 3.

---

## Step 3 — Configure the Connection in the Db2 for z/OS Developer Extension

Please make sure that you have configured the JDBC driver and license files according to the [Db2 for z/OS Developer Extension — Setting the JDBC license and JDBC driver files](https://github.com/IBM/db2forzosdeveloperextension-about#setting-the-jdbc-license-and-jdbc-driver-files) guide.

The [IBM Support page for the Db2 Connect](https://www.ibm.com/support/pages/node/7176210) may also be of interest for the various license files.

### 3a. Basic connection settings

Open the Db2 for z/OS Developer Extension in VS Code or Bob and create a new connection with the following values:

| Field         | Value                                     |
|---------------|-------------------------------------------|
| Location name | `DBD1LOC` _(from Step 1)_                |
| Hostname      | `<your-mainframe-hostname>`               |
| Port          | `8102` _(from Step 1)_                   |

### 3b. SSL / optional settings

Under the **Optional** tab, set the following JDBC properties.

| Property                | Value                                          |
|-------------------------|------------------------------------------------|
| `sslConnection`         | `true`                                         |
| `sslTrustStoreLocation` | Full path to `db2-truststore.jks` _(Step 2c)_ |
| `sslTrustStorePassword` | Truststore password set in Step 2c             |
| `sslVersion`            | `TLSv1.2`                                     |
