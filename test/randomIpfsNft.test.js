const { assert, expect } = require("chai");
const { getNamedAccounts, deployments, ethers, network } = require("hardhat");
const {
  developmentChains,
  networkConfig,
} = require("../helper-hardhat-config");

if (developmentChains.includes(network.name)) {
  describe("IPFS NFT Unit testing", function () {
    let randomIpfsNft, vrfCoordinatorV2Mock, deployer;

    beforeEach(async function () {
      accounts = await ethers.getSigners();
      deployer = accounts[0];
      await deployments.fixture(["randomipfs", "mocks"]);
      randomIpfsNft = await ethers.getContract("RandomIpfsNft");
      vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock");
      mintFee = await randomIpfsNft.getMintFee();
      beginningTokenCounter = await randomIpfsNft.getTokenCounter();
    });

    describe("constructor", function () {
      it("initializes raffle correctly", async () => {
        const dogTokenUriZero = await randomIpfsNft.getDogTokenUris(0);
        assert(dogTokenUriZero.includes("ipfs://"));
      });
    });

    describe("requestNFT", function () {
      it("reverts if minter balance is less than mint fee", async () => {
        await expect(randomIpfsNft.requestNft()).to.be.revertedWith(
          "RandomIpfsNft__NeedMoreEthSent"
        );
      });

      it("emits NftRequested if given enough eth", async () => {
        const mintFee = await randomIpfsNft.getMintFee();
        await expect(randomIpfsNft.requestNft({ value: mintFee })).to.emit(
          randomIpfsNft,
          "NftRequested"
        );
      });
    });

    describe("getBreed", function () {
      it("reverts if range is out of bounds", async () => {
        await expect(
          randomIpfsNft.getBreedFromModdedRng(200)
        ).to.be.revertedWith("RandomIpfsNft__RangeOutOfBounds()");
      });
    });
  });
} else {
  describe("Staging Tests", function () {
    //establish the variables we want to test
    let randomIpfsNft, mintFee, beginningTokenCounter, deployer;

    beforeEach(async function () {
      deployer = (await getNamedAccounts()).deployer;
      randomIpfsNft = await ethers.getContract("RandomIpfsNft", deployer);
      mintFee = await randomIpfsNft.getMintFee();
      beginningTokenCounter = await randomIpfsNft.getTokenCounter();
    });

    describe("fulfillRandomWords", function () {
      inputToConfig(
        "works with live CHainlink Keepers and Chainlink VRF, we get a random NFT",
        async function () {
          console.log("setting up test");
          //getting s_tokenCounter
          const startTokenCount = randomIpfsNft.getTokenCounter();
          const account = await ethers.getSigner();

          console.log("Setting up listener");
          await new Promise(async (resolve, reject) => {
            randomIpfsNft.once("NftMinted", async () => {
              try {
                const endingTokenCounter =
                  await randomIpfsNft.getTokenCounter();
                const minterEndingBalance = await account.getBalance();

                assert.equal(beginningTokenCounter + 1, endingTokenCounter);
                assert.equal(
                  minterEndingBalance.toString(),
                  minterStartingBalance.add(mintFee).toString()
                );
              } catch (error) {
                console.log(error);
                reject(error);
              }
            });

            console.log("Minting NFT");
            const tx = randomIpfsNft.requestNft({ value: mintFee });
            await tx.wait(1);
            console.log("Ok time to wait...");
            const minterStartingBalance = await account.getBalance();
          });
        }
      );
    });
  });
}
