# Arweave Name Token process on AO

### Building

Using the ao-dev-cli.

#### Install

```sh
curl -L https://arweave.net/iVthglhSN7G9LuJSU_h5Wy_lcEa0RE4VQmrtoBMj7Bw | bash
```

### Testing

To test the module, you can use the following command:

```sh
busted .
```

#### Build

After install, navigate to the working directory, name the entry lua file to 'process.lua', and execute `ao build`

You should recieve a 'process.wasm' file as the output in the working directory.

#### Publish

To publish the module:
Here we are manually setting the values - if you do not, it will not run. Replace the path to your JSON wallet to be relative to your location of it.

```sh
ao publish process.wasm -w ../../key.json --tag="Memory-Limit" --value="1-gb" --tag="Compute-Limit" --value="9000000000000"
```
