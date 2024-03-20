# AR.IO Network AO Experiments

## Overview

This repository is part of an experimental suite for the AR.IO Network protocols, focusing on implementing the Arweave Name System (ArNS) within the AO Supercomputer. It contains the essential processs that drive the ArNS-AO Registry, including a lightweight Name Resolver and an Arweave Name Token implementation.

## Contents

- **`src/arns.lua`**: Core process code for the Arweave Name System Registry. It handles name registrations, updates, and queries within the ArNS framework.
- **`src/arns-resolver.lua`**: A lightweight resolver process for efficiently fetching name records, owners, and associated data from the ArNS Registry.
- **`src/ant-base.lua`**: Base Arweave Name Token specification for processes that integrate with the ArNS Registry.
- **`src/ant.lua`**: The base Arweave Name Token specification plus additional management controls.

## Getting Started

For a comprehensive guide on how to utilize the ArNS Resolver, including how to map an AO Process to the ArNS Registry effectively, please refer to the [AR.IO Docs portal](https://docs.ar.io/guides/experimental/ao-resolver/). The documentation provides step-by-step instructions, best practices, and additional resources to get you started with integrating ArNS functionalities into your Arweave applications.

## Community and Support

Join the [AR.IO Experiments Discord channel](https://discord.gg/bcVkn9u45c) to share your feedback, ask questions, and connect with other developers working with the AR.IO Network protocols.
