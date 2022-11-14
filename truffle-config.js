require('dotenv').config();

const HDWalletProvider = require('@truffle/hdwallet-provider');

module.exports = {

    networks: {
        development: {
            host: "127.0.0.1",
            port: 9545,
            network_id: "*",
        },

        production: {
            provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, process.env.NODE_URL),
            network_id: 5,
            gasPrice: process.env.GAS_PRICE,
            skipDryRun: true,
            from: '0xb5F4256272D8668Dd7d1E2Ac71B156557C4CB5D3'
        }
    },

    mocha: {
        timeout: 100000
    },

    compilers: {
        solc: {
            version: "0.8.11",
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 200,
                }
            }
        }
    },

    db: {
        enabled: false,
    },

    plugins: ['truffle-plugin-verify'],

    api_keys: {
        etherscan: process.env.ETHER_SCAN_API,
    },
};