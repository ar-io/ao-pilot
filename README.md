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
    - `brew install luarocks
1. Install the dependencies by running:
    - `luarocks install --tree $HOME/.luarocks ao-0.1-1.rockspec`
1. Update your `.bashrc` or `.bash_profile` or `.zshrc` with the following:
    ```sh
    export PATH="$HOME/.luarocks/bin:$PATH"
    export LUA_PATH="$HOME/.luarocks/share/lua/5.4/?.lua;$HOME/.luarocks/share/lua/5.4/?/init.lua;"
    export LUA_CPATH="$HOME/.luarocks/lib/lua/5.4/?.so;"
    ```

`luarocks config local_by_default true`
    `luarocks path --tree .luarocks`


    `cargo install stylua`

    ### Formatting
    `stylua contract`

    ```sh
    luarocks purge && luarocks install ar-io-ao-0.1-1.rockspec
    ```

### Testing

To run the tests, execute the following command:

```sh
busted .
```

### Dependencies

To add new dependencies, install using luarocks to the local directory

```sh
luarocks install --tree $HOME.luarocks <package>
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
luarocks install --tree $HOME/.luarocks ar-io-ao-0.1-1.rockspec
``` 

### Deployment

TODO:
