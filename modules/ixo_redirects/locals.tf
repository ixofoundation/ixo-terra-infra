locals {

  hosts = {
    devnet  = ["blockscan.${terraform.workspace}.ixo.earth"]
    testnet = ["blockscan.${terraform.workspace}.ixo.earth", "blockscan-pandora.ixo.earth"]
    mainnet = ["blockscan.ixo.world"]
  }

}