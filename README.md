# IO/AO Contract
[![codecov](https://codecov.io/github/ar-io/ao-pilot/graph/badge.svg?token=0VUJ3RH9X1)](https://codecov.io/github/ar-io/ao-pilot)

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
    - `brew install lua@5.3`
1. Add the following to your `.zshrc` or `.bashrc` file:

    ```bash
    echo 'export LDFLAGS="-L/usr/local/opt/lua@5.3/lib"' >> ~/.zshrc
    echo 'export CPPFLAGS="-I/usr/local/opt/lua@5.3/include"' >> ~/.zshrc
    echo 'export PKG_CONFIG_PATH="/usr/local/opt/lua@5.3/lib/pkgconfig"' >> ~/.zshrc
    echo 'export PATH="/usr/local/opt/lua@5.3/bin:$PATH"' >> ~/.zshrc
    ```

1. Run `source ~/.zshrc` or `source ~/.bashrc` to apply the changes.
1. Run `lua -v` to verify the installation.

### Luarocks Setup

1. Install `luarocks`

    ```bash
    curl -R -O http://luarocks.github.io/luarocks/releases/luarocks-3.9.1.tar.gz
    tar zxpf luarocks-3.9.1.tar.gz
    cd luarocks-3.9.1
    ./configure --with-lua=/usr/local/opt/lua@5.3 --with-lua-include=/usr/local/opt/lua@5.3/include
    make build
    sudo make install
    ```

1. Check the installation by running `luarocks --version`.
1. Check the luarocks configuration by running `luarocks config | grep LUA`

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
