# Bank of Z - z/OS Containers Branch

> [!NOTE]
> **This branch is a work in progress.** Container support for Bank of Z is under active development and is not yet ready for general use.

## Containers on z/OS (Branch: `zos-containers`)

The aim of this branch is to use containers during the build and deployment of the Bank-of-Z application on z/OS. Containers are provided through the IBM z/OS Container Platform (zOSCP), which bundles a version of [podman](https://podman.io/) that runs in Unix System Services (USS). This branch will use podman to pull or build container images, and to run containers.

Using containers on z/OS offers several advantages over traditional installation methods:

- **Simplified installation** — each image bundles a product with its dependencies and configuration, eliminating manual install and configuration steps.
- **Consistency** — versioned, immutable images provide the same application environment across development, test, and production LPARs.
- **Dependency isolation** — runtimes are self-contained, avoiding conflicts with other products on the same USS filesystem.
- **Faster onboarding** — pull a pre-built image from a registry rather than following multi-step installation procedures.
- **Easy version control** — pin a specific product version by image tag, and roll back simply by changing it.

### Current state

| File | Status | Description |
|------|--------|-------------|
| `.setup/config/config.yaml` | ✅ Updated | New `zoscp.images` section defines the container images to pull, including the registry URL, credentials variable name, and image tag for IBM Java and IBM z/OS Connect |
| `validate-install.sh` | ✅ Updated | Checks that IBM z/OS Container Platform is installed and that podman is configured |
| `setup-zoscp-images.sh` | ✅ New | Pulls an IBM Java image and an IBM z/OS Connect image from an image registry using podman |

### What's still pending

- Integrate containers into the build pipeline
- Integrate containers into the deployment pipeline

# Bank of Z

Bank of Z is a hybrid banking application that demonstrates modern IBM Z development practices. It routes transactions through CICS or IMS depending on customer ID, with z/OS Connect as the API gateway between the browser-based UI and the z/OS transactional applications.

Full documentation is available at **[https://ibm.github.io/Bank-of-Z/](https://ibm.github.io/Bank-of-Z/)**.

## Architecture

![Bank of Z Architecture](docs/docs/about-bank-of-z/images/architecture-diagram.png)

For a detailed walkthrough of components and request flows, see the [Architecture docs](https://ibm.github.io/Bank-of-Z/docs/architecture/).

## Getting Started

> **New here? Start with the [Installation Overview →](https://ibm.github.io/Bank-of-Z/docs/installation-and-setup/)**

Or follow the full setup path step by step:

| Step | Link |
|------|------|
| 1. Review prerequisites | [Prerequisites](https://ibm.github.io/Bank-of-Z/docs/installation-and-setup/prerequisites) |
| 2. Configure your environment | [Environment Configuration](https://ibm.github.io/Bank-of-Z/docs/installation-and-setup/environment-configuration) |
| 3. Set up local tools | [Local Tools Setup](https://ibm.github.io/Bank-of-Z/docs/installation-and-setup/local-tools/) |
| 4. Deploy Bank of Z | [Deploying Bank of Z](https://ibm.github.io/Bank-of-Z/docs/installation-and-setup/deploying) |
| 5. Follow a tutorial | [Tutorials](https://ibm.github.io/Bank-of-Z/docs/tutorials/) |

## Documentation

| Topic | Description |
|-------|-------------|
| [About Bank of Z](https://ibm.github.io/Bank-of-Z/docs/about-bank-of-z/) | Purpose, capabilities, and architecture overview |
| [Architecture](https://ibm.github.io/Bank-of-Z/docs/architecture/) | Components, request flows, and external integrations |
| [Installation Overview](https://ibm.github.io/Bank-of-Z/docs/installation-and-setup/) | Installation workflow and stages |
| [Prerequisites](https://ibm.github.io/Bank-of-Z/docs/installation-and-setup/prerequisites) | Local and z/OS software requirements |
| [Environment Configuration](https://ibm.github.io/Bank-of-Z/docs/installation-and-setup/environment-configuration) | Zowe profile setup and connectivity |
| [Local Tools Setup](https://ibm.github.io/Bank-of-Z/docs/installation-and-setup/local-tools/) | IDE, Zowe CLI, and GRUB setup |
| [Deploying Bank of Z](https://ibm.github.io/Bank-of-Z/docs/installation-and-setup/deploying) | Build the application and deploy to z/OS |
| [Development Workflows](https://ibm.github.io/Bank-of-Z/docs/development-workflows/) | Zowe CLI and GRUB workflow guides |
| [Tutorials](https://ibm.github.io/Bank-of-Z/docs/tutorials/) | Deploy Bank of Z, CICS enhancement scenario |
| [Reference](https://ibm.github.io/Bank-of-Z/docs/reference/) | Commands, configuration, repository structure, glossary |
| [Troubleshooting](https://ibm.github.io/Bank-of-Z/docs/troubleshooting/) | Common issues and solutions |

## Contributing

This is a sample application for demonstration purposes. Feel free to fork the repository, customise it for your environment, add new features or programs, and share improvements.

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.
