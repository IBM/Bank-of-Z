---
layout: default
title: Glossary
---

# Glossary

This glossary defines common terms and technologies used throughout the Bank of Z documentation.

| Term | Definition |
|------|------------|
| **Account History Db2 Database** | A Db2 database used by Bank of Z to store historical account and transaction information for inquiry and reporting functions. |
| **API** | Application Programming Interface. A defined interface that enables applications and services to communicate with each other. |
| **Bank of Q** | A sample external banking system used to demonstrate inter-application communication and money transfer scenarios through IBM MQ. |
| **Bank of Z** | A sample hybrid banking application that demonstrates modern z/OS application development, integration, build, deployment, and operational workflows. |
| **BMS** | Basic Mapping Support. A CICS facility used to define terminal screen layouts and user interactions. |
| **Bob IDE** | IBM Premium Bob for Z, an integrated development environment that supports IBM Z application development workflows. |
| **CICS** | Customer Information Control System. An IBM transaction-processing system used to execute online business transactions. In Bank of Z, customers with identifiers beginning with `C` are routed to CICS transactions. |
| **COBOL** | Common Business-Oriented Language. The primary programming language used for the Bank of Z business logic. |
| **Copybook** | A reusable source file containing data structure definitions shared across COBOL programs. |
| **Customer Routing** | The Bank of Z mechanism that routes requests to either CICS or IMS TM based on the customer identifier pattern. |
| **DBB** | IBM Dependency Based Build. A build framework used to compile, link, and manage z/OS application builds. |
| **Db2** | IBM Db2 for z/OS. A relational database used to store customer, account, and transaction information. |
| **Git** | A distributed version control system used to manage source code and support collaborative development. |
| **GRUB** | Git Remote User Build. A workflow that synchronizes local changes to z/OS USS and runs setup and build processes without requiring commits for every change. |
| **Hybrid Architecture** | An application architecture that integrates multiple transaction-processing environments and technologies into a unified user experience. In Bank of Z, requests are processed through either CICS or IMS TM while sharing common services and data resources. |
| **IBM MQ** | IBM messaging middleware used for asynchronous communication between applications and external systems. |
| **IMS DB** | IBM Information Management System Database. A hierarchical database used by the IMS processing path within Bank of Z. |
| **IMS TM** | IBM Information Management System Transaction Manager. A transaction-processing environment used by Bank of Z. Customers with identifiers beginning with `I` are routed to IMS TM transactions. |
| **JVM** | Java Virtual Machine. The runtime environment used to execute Java applications and services. |
| **ODE** | On-Demand Environment. A preconfigured development and testing environment used to provision and run Bank of Z components. |
| **Pipeline** | An automated sequence of build, packaging, deployment, and validation activities executed through Bank of Z development workflows. |
| **RSE API** | Remote System Explorer API. A service used by Zowe CLI and development tools to interact with z/OS resources. |
| **USS** | UNIX System Services. The POSIX-compliant environment within z/OS used to host source code, scripts, build artifacts, and application assets. |
| **VS Code** | Visual Studio Code. A development environment commonly used to develop, build, and manage Bank of Z assets. |
| **Wazi Deploy** | IBM deployment automation tooling used to deploy application artifacts and configuration changes. |
| **Workflow** | A defined development process used to build, deploy, test, and validate application changes. Bank of Z supports VS Code and GRUB workflows. |
| **zBuilder** | A build framework used with DBB to automate compilation, linking, and build orchestration for z/OS applications. |
| **ZCodeScan** | A static analysis tool used to analyze source code quality and identify potential issues. |
| **z/OS Connect** | An API framework that enables REST-based access to z/OS applications and services. In Bank of Z, it provides the interface between the web application and the CICS and IMS transaction environments. |
| **ZOAU** | IBM Z Open Automation Utilities. A collection of utilities and APIs used to automate z/OS administration and development tasks. |
| **Zowe CLI** | A command-line interface used to interact with z/OS systems, services, datasets, USS files, and development workflows. |