# Arweave Name Token process on AO

This repository provides two flavours of ANT process module, AOS and a custom module.

## Setup

### Install

First install the npm dependencies

```bash
yarn
```

Then install the ao cli - read the docs [here](https://github.com/permaweb/ao/tree/main/dev-cli)
Below is latest version as of writing, refer to the docs for the latest version.

```sh
curl -L https://arweave.net/iVthglhSN7G9LuJSU_h5Wy_lcEa0RE4VQmrtoBMj7Bw | bash
```

You may need to follow the instructions in the cli to add the program to your PATH.

### Testing

To test the module, you can use the following command to run [busted](https://lunarmodules.github.io/busted/)

```sh
busted .
```

### Building the AOS code

#### Build

This bundles the ant-aos code and outputs it to `dist` folder. This can then be used to send to the `Eval` method on AOS to load the ANT source code.

```bash
yarn build:aos-ant
```

#### Publish

Ensure that in the `tools` directory you place you Arweave JWK as `key.json`

```bash
yarn publish:aos-ant
```

#### Load

This will load an AOS module into the loader, followed by the bundled aos-ant Lua file to verify that it is a valid build.

```bash
yarn load:aos-ant
```

#### Spawn

this will spawn an aos process and load the bundled lua code into it.

```bash
yarn spawn:aos-ant
```

This will deploy the bundled lua file to arweave as an L1 transaction, so your wallet will need AR to pay the gas.

### Building the custom module

Using the ao-dev-cli.

#### Build

This will compile the standalone ANT module to wasm, as a file named `process.wasm` and loads the module in [AO Loader](https://github.com/permaweb/ao/tree/main/loader) to validate the WASM program is valid.

```bash
yarn build:module
```

#### Publish

Publishes the custom ANT module to arweave - requires you placed your JWK in the `tools` directory. May require AR in the wallet to pay gas.

```sh
yarn publish:module
```

#### Load

Loads the module in [AO Loader](https://github.com/permaweb/ao/tree/main/loader) to validate the WASM program is valid.

```bash
yarn load:module
```

Requires `build:module` to have been called so that `process.wasm` exists.

#### Spawn

Spawns a process with the `process.wasm` file.

```bash
yarn spawn:module
```
