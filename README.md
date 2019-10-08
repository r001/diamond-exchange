# CDiamondcoin Diamond Exchange Smart Contract

One of the main goal of [Diamond Network Project](https://cdiamondcoin.com/) is to create a diamond backed stable coin. In order to enable this an exchange is needed where users can buy and sell their diamonds on the chain while the physical diamonds are sored in safe and regularly audited sotres. This smart contract can handle both investment diamonds and the CDC stablecoin. 

## Prerequisities

In order to compile smart contracts you need to install [Dapphub](https://dapphub.com/)'s utilities. Namely: [dapp](https://dapp.tools/dapp/), [seth](https://dapp.tools/seth/), [solc](https://github.com/ethereum/solidity), [hevm](https://dapp.tools/hevm/), and [ethsign](https://github.com/dapphub/dapptools/tree/master/src/ethsign).

| Command | Description |
| --- | --- |
|`bash <(curl https://nixos.org/nix/install)` | install `nix` package manager.|
|`. "$HOME/.nix-profile/etc/profile.d/nix.sh"`| load config for `nix`|
|`git clone --recursive https://github.com/dapphub/dapptools $HOME/.dapp/dapptools` | download `dapp seth solc hevm ethsign` utilities|
|`nix-env -f $HOME/.dapp/dapptools -iA dapp seth solc hevm ethsign` | install `dapp seth solc hevm ethsign`. This will install utilities for current user only!!|

## Use custom version of solidity compiler

`dapp --use solc:0.5.11 build`

## Building smart contracts

The `build` command invokes `solc` to compile all code in `src` and `lib` to `out`.

`dapp build`

## Installing smart contracts

As a result of installation .abi and .bin files will be created in `cdc-token/out/` folder. These files can be installed later on mainnet.

| Command | Description |
| --- | --- |
|`git clone https://github.com/Cdiamondcoin/diamond-exchange.git` | Clone the smart contract code.|
|`cd diamond-exchange && git submodule update --init --recursive` | Update libraries to the latest version.|
|`dapp test` | Compile and test the smart contracts.|

## Deploying smart contracts

TBD.

## Authors

- [Robert Horvath](https://github.com/r001)
- [Vitālijs Gaičuks](https://github.com/vgaicuks)
- [Aleksejs Osovitnijs](https://github.com/alexxxxey)

## License

This project is licensed under the GPL v3 License - see the [LICENSE](LICENSE) for details.
