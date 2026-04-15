# CBSA API Migration Notes

## What is in this project

[cbsa-api](src/baseApi/cbsa-api/) is a z/OS Connect API project for the CBSA CICS application. It includes:

- an OpenAPI definition in [src/main/api/openapi.yaml](src/baseApi/cbsa-api/src/main/api/openapi.yaml)
- z/OS Connect operation mappings in [src/main/operations/](src/baseApi/cbsa-api/src/main/operations/)
- CICS provider assets in [src/main/zosAssets/](src/baseApi/cbsa-api/src/main/zosAssets/)
- Liberty server configuration in [src/main/liberty/config/](src/baseApi/cbsa-api/src/main/liberty/config/)
- a validation script in [scripts/test-banking-apis.sh](src/baseApi/cbsa-api/scripts/test-banking-apis.sh)

The project exposes 11 CBSA operations backed by CICS programs such as `CREACC`, `CRECUST`, `INQACC`, `INQCUST`, `UPDACC`, `UPDCUST`, `DELACC`, `DELCUS`, `DBCRFUN`, and `XFRFUN`.

## Base source comparison

Bank-of-Z CICS source in [src/base/cics/](src/base/cics/) is effectively the same as the legacy CBSA application source for COBOL, copybooks, and maps, with these file-level differences:

- BMS: [BNK1B2M.bms](src/base/cics/bms/BNK1B2M.bms) exists in Bank-of-Z only
- COBOL: no file-level differences were found

## OpenAPI comparison


### Current [src/api/](src/api/) spec

- Open Banking style placeholder API
- read-only customer/account/balance/transaction endpoints
- OAuth2/security scheme definitions
- generic public URLs such as `https://api.bankofz.com/v1`
- no CBSA-specific z/OS Connect assembly or provider integration

### Imported [cbsa-api](src/baseApi/cbsa-api/) spec

- z/OS Connect-ready CBSA API definition
- 11 implemented CICS-backed operations:
  - `/creacc/insert`
  - `/crecust/insert`
  - `/delacc/remove/{accno}`
  - `/delcus/remove/{custno}`
  - `/inqaccz/enquiry/{accno}`
  - `/inqacccz/list/{custno}`
  - `/inqcustz/enquiry/{custno}`
  - `/makepayment/dbcr`
  - `/transfer/funds`
  - `/updacc/update`
  - `/updcust/update`
- direct invoke target of `cics://cbsaCicsConnection`
- request/response schemas aligned to CBSA commareas and generated copybooks

## System-specific values to review before reuse

These values are specific to the source environment and should be changed when incorporating this project:

### OpenAPI and gateway config

- local server URLs in [openapi.yaml](src/baseApi/cbsa-api/src/main/api/openapi.yaml): `https://localhost:8080/banking` and `http://localhost:8080/banking`
- CICS invoke target in [openapi.yaml](src/baseApi/cbsa-api/src/main/api/openapi.yaml): `cics://cbsaCicsConnection`

### Liberty override config

In [src/main/liberty/config/configDropins/overrides/server.xml](src/baseApi/cbsa-api/src/main/liberty/config/configDropins/overrides/server.xml):

- HTTP port `30701`
- CICS IPIC host `localhost`
- CICS IPIC port `30711`
- application id/name `banking-api`
- hardcoded credentials `IBMUSER` / `SYS1SYS1`

* Note that this override is important because the server.xml in the liberty/config directory will be overridden during the build to be the base default server.xml and this override option has some specific setup needed to run the application on our environment.

### z/OS asset bindings

In provider configs such as [CREACC/zosAsset.yaml](src/baseApi/cbsa-api/src/main/zosAssets/CREACC/zosAsset.yaml) and [INQACC/zosAsset.yaml](src/baseApi/cbsa-api/src/main/zosAssets/INQACC/zosAsset.yaml):

- connection reference `cbsaCicsConnection`
- transaction id `OMEN`
- program names tied to the CBSA CICS programs
- CCSID `037`

### Test script

In [scripts/test-banking-apis.sh](src/baseApi/cbsa-api/scripts/test-banking-apis.sh):

- `BASE_URL` points to `http://lp25-zhss117.pok.stglabs.ibm.com:30701`
- payload values assume CBSA data formats and sort code usage
- the script depends on [`jq`](language.construct:1) and a working deployed API

## How to run

From [src/baseApi/cbsa-api/](src/baseApi/cbsa-api/):

```bash
./gradlew build
```

If you want to deploy/run with Liberty, first update the environment-specific settings above, then use the z/OS Connect/Liberty workflow your team is using for [src/api/](src/api/). The old generated README referenced Maven, but this project is now Gradle-based via [build.gradle](src/baseApi/cbsa-api/build.gradle).

To run the API validation script after deployment:

```bash
bash scripts/test-banking-apis.sh
```

## What the script does

[test-banking-apis.sh](src/baseApi/cbsa-api/scripts/test-banking-apis.sh) runs an end-to-end sequence against the deployed API:

1. create customer
2. enquire customer
3. create two accounts
4. enquire account
5. list customer accounts
6. update customer
7. update account
8. make payment
9. transfer funds
10. delete accounts
11. delete customer

It captures generated customer/account numbers from responses and reuses them in later calls.

## Recommended incorporation steps for [src/api/](src/api/)

1. Replace the placeholder Open Banking spec in [src/api/src/main/api/openapi.yaml](src/api/src/main/api/openapi.yaml) with the CBSA implementation, or merge the CBSA paths into the target design.
2. Copy over the completed z/OS Connect assets from [src/baseApi/cbsa-api/src/main/operations/](src/baseApi/cbsa-api/src/main/operations/) and [src/baseApi/cbsa-api/src/main/zosAssets/](src/baseApi/cbsa-api/src/main/zosAssets/).
3. Add the Liberty configuration needed for the CICS connection from [src/baseApi/cbsa-api/src/main/liberty/config/](src/baseApi/cbsa-api/src/main/liberty/config/).
4. Replace all source-environment values before committing:
   - host names
   - ports
   - credentials
   - server URLs
   - connection ids if naming needs to change
5. Align Gradle config in [src/api/build.gradle](src/api/build.gradle) with [src/baseApi/cbsa-api/build.gradle](src/baseApi/cbsa-api/build.gradle), especially the plugin version and task dependency fix for OpenAPI generation.
6. Re-test using [test-banking-apis.sh](src/baseApi/cbsa-api/scripts/test-banking-apis.sh) after the API is deployed in the new environment.
