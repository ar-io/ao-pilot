# IO/AO Contract

This repository contains the IO contract implementation on AO.

## Components

- Arweave Name System (ArNS) Registry - Core process code for the Arweave Name System Registry. It handles name registrations, updates, and queries within the ArNS framework.
- Gateway Registry - Lua module that handles the registration and management of AR.IO Gateways.
- Balances - Lua module that manages the balances of IO token holders.

## Developers

### Requirements

- Lua 5.3 - [Download](https://www.lua.org/download.html)
- Luarocks - [Download](https://luarocks.org/)

### Lua Setup

1. Clone the repository and navigate to the project directory.
1. Install `lua`
    - `brew install lua`
1. Install `luarocks`
    - `brew install luarocks`
1. Set the local luarocks path
    - `luarocks config local_by_default true`
    - `luarocks path --tree .luarocks`
1. Install the dependencies by running:
    - `luarocks install ar-io-ao-0.1-1.rockspec`

If you ever need to refresh .luarocks, run the following command:

```sh
luarocks purge && luarocks install ar-io-ao-0.1-1.rockspec
```

### aos

To load the module into the `aos` REPL, run the following command:

```sh
aos --load contract/src/main.lua
```

### Code Formatting

The code is formatted using `stylua`. To install `stylua`, run the following command:

```sh
cargo install stylua
stylua contract
```

### Testing

To run the tests, execute the following command:

```sh
busted .
```

### Dependencies

To add new dependencies, install using luarocks to the local directory

```sh
luarocks install <package>
```

And add the package to the `dependencies` table in the `ar-io-ao-0.1-1.rockspec` file.

```lua
    -- rest of the file
    dependencies = {
        "lua >= 5.3",
        "luaunit >= 3.3.0",
        "<package>"
    }
```

### Deployment

TODO:
