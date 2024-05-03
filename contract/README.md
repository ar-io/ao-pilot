# IO/AO Contract

This repository contains the IO contract implementation on AO.

## Components

- Arweave Name System (ArNS) Registry - Core process code for the Arweave Name System Registry. It handles name registrations, updates, and queries within the ArNS framework.
- Gateway Registry - Lua module that handles the registration and management of AR.IO Gateways.
- Balances - Lua module that manages the balances of IO token holders.

## Developers

### Requirements

- npm - [Download](https://www.npmjs.com/get-npm)
- Lua 5.3 - [Download](https://www.lua.org/download.html)
- Luarocks - [Download](https://luarocks.org/)
- AOS:
    `npm i -g https://get_ao.g8way.io`

### Setup

1. Clone the repository and navigate to the project directory.
2. Install the Lua dependencies by running `luarocks install luaunit`.
3. Install the AOS CLI by running `npm i -g https://get_ao.g8way.io`.

Install the dependencies by running:

```sh
luarocks install --tree .luarocks ar-io-ao-0.1-1.rockspec
```

### Testing

To run the tests, execute the following command:

```sh
lua test.lua
```

### Deployment

TODO:
