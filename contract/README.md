# IO/AO Contract

This repository contains the IO contract implementation on AO.

## Components

- Arweave Name System (ArNS) Registry - Core process code for the Arweave Name System Registry. It handles name registrations, updates, and queries within the ArNS framework.
- Gateway Registry - Lua module that handles the registration and management of AR.IO Gateways.
- Balances - Lua module that manages the balances of IO token holders.

## Developers

### Requirements

- Lua 5.3 - [Download](https://www.lua.org/download.html)
    > `brew install lua`
- Luarocks - [Download](https://luarocks.org/)
    > `brew install luarocks`

### Lua Setup

1. Clone the repository and navigate to the project directory.
1. Install `lua`
1. Install `luarocks`
1. Update your `LUAROCKS_PATH` to include the local directory by running `export LUAROCKS_PATH=$LUAROCKS_PATH:$(pwd)/.luarocks`.
1. Update your `LUA_PATH` to include the local directory by running `export LUA_PATH=$LUA_PATH:$(pwd)/.luarocks/share/lua/5.3/?.lua`.

```sh
export LUA_PATH=$LUA_PATH:$(pwd)/.luarocks/share/lua/5.3/?.lua
```

<!-- TODO: update path variables here? -->

### Project Setup

Install the dependencies by running:

```sh
luarocks install --tree .luarocks ar-io-ao-0.1-1.rockspec
```

### Testing

To run the tests, execute the following command:

```sh
busted .
```

### Dependencies

To add new dependencies, install using luarocks to the local directory

```sh
luarocks install --tree .luarocks <package>
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

Validate the changes by running:

```sh
luarocks install --tree .luarocks ar-io-ao-0.1-1.rockspec
``` 

### Deployment

TODO:
