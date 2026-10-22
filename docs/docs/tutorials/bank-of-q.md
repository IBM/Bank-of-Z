---
layout: default
title: Bank of Q
---

# Bank of Q

## Overview

In this tutorial, you will run the Bank of Q Java code which simulates an external bank transferring money to or from an account in Bank of Z via MQ.

## Prerequisites
Before starting this tutorial, ensure that you have:

- Completed the Deploy Bank of Z tutorial
- Successfully built and deployed Bank of Z
- A working Bank of Z development environment
- Access to the Bank of Z Git repository and z/OS USS environment

## What you learn

By completing this tutorial, you learn how to run the Bank of Q Java code.

## Part 1: Set up your environment
Log in to USS and make sure that your STEPLIB contains MQ's SCSQAUTH data set, and that MQ's USS native libraries are in your LIBPATH. Additionally ensure the CLASSPATH contains the jar files for MQ's JMS implementation, and the Bank of Q.

```bash
export SANDBOXES_DIR=/usr/local/sandboxes
export MQINSTALL=$SANDBOXES_DIR/tools/mq/java/lib
export STEPLIB=MQCD94.SCSQAUTH:$STEPLIB
export LIBPATH=$MQINSTALL:$LIBPATH
export CLASSPATH=$MQINSTALL/jakarta.jms-api.jar:$MQINSTALL/com.ibm.mq.jakarta.client.jar:$SANDBOXES_DIR/bank-of-z/jars/boq-1.0.0-SNAPSHOT.jar
```

## Part 2: Transfer money from Bank of Q to Bank of Z
The Bank of Q Java code takes four parameters:

- A queue manager name, e.g. MQ21
- An customer ID starting with either a C or an I, e.g. C6
- An account number, e.g. 00000008
- An amount to transfer into Bank of Z in dollars and cents, e.g. 10.10. A negative value means the money is being transferred out of Bank of Z, e.g. -100.10

The following command shows how to transfer $99.99 via a CICS based account:

```bash
java  com.ibm.boq.TransferMoneyToBOZ MQ21 C6 8 99.99
```

The following command shows how to transfer $50.04 via an IMS based account:

```bash
java  com.ibm.boq.TransferMoneyToBOZ MQ21 I15 1504 50.04
```

## Outcome

After completing this tutorial, you will have transferred money from two accounts in the Bank of Q to the Bank of Z.