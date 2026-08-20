# AGENTS.md — MortgageApplication

This file provides context for AI agents (Bob, Copilot, etc.) working in this repository.

## Project Overview

**MortgageApplication** is an IBM z/OS CICS sample application built with
[IBM DBB zAppBuild](https://github.com/IBM/dbb-zappbuild). It demonstrates a
COBOL/BMS/CICS mortgage processing application and serves as a reference for
DBB pipeline build configurations.

## Repository Structure

```
MortgageApp-zBuilder/
├── application-conf/       # DBB zAppBuild build configuration properties
│   ├── application.properties          # Core build settings and search paths
│   ├── file.properties                 # Script mappings and file-level overrides
│   ├── Cobol.properties                # COBOL compiler and link-edit defaults
│   ├── BMS.properties                  # BMS map assembly parameters
│   ├── LinkEdit.properties             # Link-card build parameters
│   ├── CRB.properties                  # CICS Resource Builder settings
│   └── languageConfigurationMapping.properties  # Per-file language config overrides
├── src/
│   ├── bms/                # BMS map source files (*.bms)
│   ├── cobol/              # COBOL source programs (*.cbl)
│   ├── copybook/           # COBOL copybooks (*.cpy)
│   ├── crb/                # CICS Resource Builder definitions (*.yaml)
│   ├── link/               # Link-edit control cards (*.lnk)
│   └── properties/         # Artifact-level property overrides (*.properties)
├── zapp.yaml               # Z Open Editor property group configuration
├── zowe.config.json        # Zowe CLI team configuration (host, ports, auth)
└── zowe.schema.json        # JSON schema for zowe.config.json validation
```

## Source Programs

| Program | Type | Description |
|---------|------|-------------|
| [`epscmort.cbl`](src/cobol/epscmort.cbl) | COBOL/CICS | Main mortgage calculation program |
| [`epscsmrd.cbl`](src/cobol/epscsmrd.cbl) | COBOL | Mortgage data reader |
| [`epscsmrt.cbl`](src/cobol/epscsmrt.cbl) | COBOL/CICS | Mortgage data sort/transform |
| [`epsmlist.cbl`](src/cobol/epsmlist.cbl) | COBOL/CICS | Mortgage list display program |
| [`epsmpmt.cbl`](src/cobol/epsmpmt.cbl) | COBOL/CICS | Mortgage payment calculation |
| [`epsnbrvl.cbl`](src/cobol/epsnbrvl.cbl) | COBOL | Number validation submodule |
| [`epsmort.bms`](src/bms/epsmort.bms) | BMS | Mortgage entry map |
| [`epsmlis.bms`](src/bms/epsmlis.bms) | BMS | Mortgage list map |
| [`epsmlist.lnk`](src/link/epsmlist.lnk) | LinkEdit | Link card for EPSMLIST load module |

## Build Configuration Notes

- Build framework: **IBM DBB zAppBuild**
- Build order: `BMS.groovy` → `Cobol.groovy` → `LinkEdit.groovy`
- Main build branch: `main`
- `epsnbrvl.cbl` must compile first (build rank 1) — it is a static submodule
- `epsnbrvl.cbl` and `epsmlist.cbl` do **not** produce standalone load modules (`cobol_linkEdit=false`)
- `epsmlist.cbl`, `epsmlist.lnk`, and `epscsmrt.cbl` are flagged `isCICS=true` via file properties
- Artifact-level property override: [`src/properties/epsmlist.cbl.properties`](src/properties/epsmlist.cbl.properties)

## Data Dictionary

- Location: `bobz/DD.json` (created by Bob's data dictionary workflow)
- Full path: `/Users/davidrice/git/MortgageApp-zBuilder/bobz/DD.json`
- If `bobz/DD.json` does not exist, run the data dictionary workflow before analyzing COBOL or PL/I files

## z/OS Connection

Configured via [`zowe.config.json`](zowe.config.json):
- **Host**: `esysmvs1.wsclab.washington.ibm.com`
- **z/OSMF port**: 443
- **SSH port**: 22
- **RSE API port**: 6800
- Credentials are stored securely (not in the config file)

## Conventions

- All COBOL programs use the `EPSM`/`EPSC`/`EPSN` prefix naming convention
- Copybooks use the `.cpy` extension and live in `src/copybook/`
- Copybook search path: `search:${workspace}/?path=${application}/copybook/*.cpy`
- BMS search path: `search:${workspace}/?path=${application}/bms/*.bms`
