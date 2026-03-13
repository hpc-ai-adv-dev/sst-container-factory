# AHP JSON Writing Container Build

This directory contains the `Containerfile` for building a container that uses [ahp_graph](https://github.com/alvaradoo/ahp_graph). Primary developed for the JSON writing experiment found at https://github.com/hpc-ai-adv-dev/sst-experiment-ahp-json-writing. 

## What It Builds

The container is based on `ghcr.io/hpc-ai-adv-dev/sst-core:15.1.2` and
adds:

- Build tools (`autoconf`, `cmake`, `libtool`)
- Graphviz and its development headers
- [ahp_graph](https://github.com/alvaradoo/ahp_graph) (Python package)
- matplotlib
- The [PHOLD benchmark](https://github.com/hpc-ai-adv-dev/sst-benchmarks) (compiled)
