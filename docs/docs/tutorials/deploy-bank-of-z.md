---
layout: default
title: Deploy Bank of Z
---

# Deploy Bank of Z

The following video demonstrates a complete first-time deployment of Bank of Z using the Direct USS deployment workflow. Starting from a z/OS environment that meets all prerequisites, this video walks through cloning the repository to z/OS USS and running the three setup stages. This stages automatically provision the application environment, including CICS, IMS, z/OS Connect, and a Liberty frontend server, then build and deploy the application from source.

<video controls width="100%" style="max-width: 960px;">
  <source src="https://github.com/IBM/Bank-of-Z/releases/download/v1/bank_of_z_quick_start.mov" type="video/mp4">
  Your browser does not support the video tag.
</video>

To deploy Bank of Z yourself, see [Deploying Bank of Z](../installation-and-setup/deploying.html).

**Tip:** After the initial deployment, use the incremental build and deploy workflow (`pipeline-remote.sh`) for day-to-day development instead of performing a full deployment after every code change.