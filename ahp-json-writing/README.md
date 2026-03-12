# AHP Graph — Container Build

This directory contains the `Containerfile` for building a container that
generally uses [ahp_graph](https://github.com/alvaradoo/ahp_graph).

## What It Builds

The container is based on `ghcr.io/hpc-ai-adv-dev/sst-core:15.1.2` and
adds:

- Build tools (`autoconf`, `cmake`, `libtool`)
- Graphviz and its development headers
- [ahp_graph](https://github.com/alvaradoo/ahp_graph) (Python package)
- matplotlib
- The [PHOLD benchmark](https://github.com/hpc-ai-adv-dev/sst-benchmarks) (compiled)
