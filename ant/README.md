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

### Building the custom module

Using the ao-dev-cli.

#### Build

```bash
yarn build
```

#### Publish

To publish the module:
Here we are manually setting the values - if you do not, it will not run. Replace the path to your JSON wallet to be relative to your location of it.

```sh
ao publish process.wasm -w ../../key.json --tag="Memory-Limit" --value="1-gb" --tag="Compute-Limit" --value="9000000000000"
```
