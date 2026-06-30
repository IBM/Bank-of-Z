---
layout: default
title: Architecture Overview
---

# Architecture Overview

Bank of Z uses a hybrid architecture that combines modern web technologies with IBM Z transaction-processing systems. The application provides a browser-based interface that communicates with backend services through z/OS Connect.

Banking operations are processed by either CICS or IMS Transaction Manager (IMS TM), depending on the transaction path. These transaction environments access shared banking data and integrate with external systems through IBM MQ.

This architecture demonstrates how multiple IBM Z technologies can be combined to deliver a unified application experience while supporting modern development and deployment practices.

![Architecture Diagram](images/architecture-diagram.jpg)

