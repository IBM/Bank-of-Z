---
layout: default
title: Application Components
---

# Application Components

Bank of Z consists of several application and infrastructure components that work together to provide a unified banking experience. These components enable the application to deliver modern web-based banking services while leveraging IBM Z transaction-processing technologies.

## Bank of Z UI

The Bank of Z user interface provides a browser-based experience for performing banking operations. You can manage customer information, accounts, and transactions through a single application interface without needing to know which backend system processes the request.

## z/OS Connect

z/OS Connect provides the API layer between the user interface and the backend transaction-processing systems. It exposes services that enable the Bank of Z UI to communicate with CICS and IMS applications through REST APIs.

## CICS

CICS provides transaction-processing services for the Bank of Z application. It processes banking requests, including customer management, account management, and transaction processing, using the CICS processing path.

## Money and Account Management IMS Database

The Money and Account Management IMS database supports account management functions for the IMS processing path. It enables IMS applications to manage and retrieve customer and account information.

## IMS Transaction Manager (IMS TM)

IMS TM provides transaction-processing services for the Bank of Z application. It processes banking requests, including customer management, account management, and transaction processing, using the IMS processing path.

## Money and Account Management Db2 Database

The Money and Account Management Db2 database stores account and transaction data used by the application. It serves as the primary data store for the CICS processing path and is also accessed by IMS-based transactions.

## Account History Db2 Database

The Account History Db2 database stores historical account and transaction information used for inquiry and reporting functions.

## IBM MQ

IBM MQ provides messaging capabilities that enable asynchronous communication between Bank of Z and external systems. It supports integration scenarios that require reliable message delivery and decoupled processing.

## Bank of Q

Bank of Q represents an external banking system that exchanges information with Bank of Z through IBM MQ. It is used to demonstrate inter-application communication and money transfer scenarios.

## Component Relationships

The Bank of Z UI communicates with z/OS Connect through REST APIs. z/OS Connect provides access to the underlying transaction-processing environments, where business logic executes and data is stored in Db2 for z/OS and IMS databases. IBM MQ supports asynchronous communication with external systems.

Together, these components provide a hybrid IBM Z application that combines modern user interfaces, API-driven integration, enterprise transaction processing, and shared data services.