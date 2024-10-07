[![tests](https://github.com/rfay/ddev-ibexa-cloud/actions/workflows/tests.yml/badge.svg)](https://github.com/rfay/ddev-ibexa-cloud/actions/workflows/tests.yml) ![project is maintained](https://img.shields.io/maintenance/yes/2025.svg)

The [Ibexa Cloud](https://www.ibexa.co/products/ibexa-cloud) has its own CLI, instead of using the `platform` CLI.

This add-on provides integration for Ibexa Cloud.

1. Configure your Ibexa project for DDEV if you haven't already, see [DDEV Ibexa Quickstart](https://ddev.readthedocs.io/en/stable/users/quickstart/#ibexa-dxp)
2. `ddev get rfay/ddev-ibexa-cloud` (# or in DDEV v1.23.5+ `ddev add-on get rfay/ddev-ibexa-cloud`)
3. Configure your IBEXA_CLI_TOKEN globally, `ddev config global --web-environment-add=IBEXA_CLI_TOKEN=nf4amudfn23biyourtoken`
4. Configure your IBEXA_PROJECT, IBEXA_ENVIRONMENT, and IBEXA_APP environment variables, for example `ddev config --web-environment-add=IBEXA_PROJECT=nf4amudfn23biyourproject,IBEXA_ENVIRONMENT=main,IBEXA_APP=app`
5. `ddev restart`
6. `ddev pull ibexa-cloud`

## Running Automated Tests Locally

* `IBEXA_CLI_TOKEN`, `IBEXA_PROJECT` and `IBEXA_ENVIRONMENT` should exist in the environment


**Contributed and maintained by @rfay**
