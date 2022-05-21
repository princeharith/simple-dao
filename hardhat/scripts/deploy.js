const { ethers } = require("hardhat");
const { CRYPTODEVS_NFT_CONTRACT_ADDRESS } = require("../constants");
require("@nomiclabs/hardhat-etherscan");

async function main() {
    //deploy the FakeNFTMarketplace contract first
    const FakeNFTMarketplace = await ethers.getContractFactory (
        "FakeNFTMarketplace"
    );

    const fakeNftMarketplace = await FakeNFTMarketplace.deploy();
    await fakeNftMarketplace.deployed();

    console.log("FakeNFTMarketplace deployed to: ", fakeNftMarketplace.address);

    //deploying the DAO contract
    const CryptoDevsDAO = await ethers.getContractFactory("CryptoDevsDAO");
    const cryptoDevsDAO = await CryptoDevsDAO.deploy(
        fakeNftMarketplace.address,
        CRYPTODEVS_NFT_CONTRACT_ADDRESS,
        {
            value: ethers.utils.parseEther(".001"),
        }
    );
    await cryptoDevsDAO.deployed();

    console.log("DAO contract deployed to: ", cryptoDevsDAO.address);

    console.log("Sleeping.....");
    // Wait for etherscan to notice that the contract has been deployed
    await sleep(60000);

    // Verify the contract after deploying
    await hre.run("verify:verify", {
        address: cryptoDevsDAO.address,
        constructorArguments: [
            fakeNftMarketplace.address,
            CRYPTODEVS_NFT_CONTRACT_ADDRESS,
        ],
    });

}

function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })