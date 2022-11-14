const AkshunStore_Contract = artifacts.require("AkshunStore");
// const Akshun_Contract = artifacts.require("Akshun");

module.exports = function(deployer) {
  deployer.deploy(AkshunStore_Contract);
  // deployer.deploy(Akshun_Contract, 'AkshunNFT', 'AKSHUN', 'ipfs://bafybeidlkqhddsjrdue7y3dy27pu5d7ydyemcls4z24szlyik3we7vqvam/nft-image.png');
};