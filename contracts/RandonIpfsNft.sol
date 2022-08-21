// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

//Importing consumber base v2 and vrfCoordinator v2
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
//we are using ERC721URIStorage contract as it has a function called _getTokenURI
//which will allow us to call the token URI and use it to select the image for the Randomly selected NFT
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
//Ownable will allow us to modify and only select the owner
import "@openzeppelin/contracts/access/Ownable.sol";

error RandomIpfsNft__RangeOutOfBounds();
error RandomIpfsNft__NeedMoreEthSent();
error RandomIpfsNft__TransferFailed();

contract RandomIpfsNft is VRFConsumerBaseV2, ERC721URIStorage, Ownable {
  //when we mint an NFT, we will trigger a Chainlink VRF call
  // to get a random number
  // using that number, we will get a random NFT
  //Choices will be
  // Pug -> super rare
  // Shiba -> sort of rare
  // St. Bernard -> least rare

  //Type Declaration
  //creating an enum to distinguish between the 3 dog types
  enum Breed {
    PUG, //-> 0
    SHIBA_INU, // -> 1
    ST_BERNARD // -> 2
  }

  //will request user to get NFT

  VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
  uint64 private immutable i_subscriptionId;
  bytes32 private immutable i_gasLane;
  uint32 private immutable i_callbackGasLimit;
  uint16 private constant REQUEST_CONFIRMATIONS = 3;
  uint32 private constant NUM_WORDS = 1;

  //VRF Helpers
  // we want to create a mapping between requestId and the person who called the requestNFT to
  mapping(uint256 => address) public s_requestIdToSender;

  //NFT Variables
  //counter for token
  uint256 public s_tokenCounter;
  uint256 public constant MAX_CHANCE_VALUE = 100;
  //create array that will represent a list of holding the URL/URI that point to the images for the dogs
  string[] internal s_dogTokenUris;
  //setting an immutable mint fee
  uint256 internal immutable i_mintFee;

  //Events
  event NftRequested(uint256 indexed requestId, address requester);
  event NftMinted(Breed dogBreed, address minter);

  constructor(
    address vrfCoordinatorV2,
    uint64 subscriptionId,
    bytes32 gasLane,
    uint32 callbackGasLimit,
    string[3] memory dogTokenUris,
    uint256 mintFee
  ) VRFConsumerBaseV2(vrfCoordinatorV2) ERC721("Random IPFS NFT", "RIN") {
    i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
    //these will all be either codified or coded in based on Chainlink VRF subscription
    //link to VRF subscriptionId -> https://vrf.chain.link/mainnet
    i_subscriptionId = subscriptionId;
    i_gasLane = gasLane;
    i_callbackGasLimit = callbackGasLimit;
    i_mintFee = mintFee;
    s_dogTokenUris = dogTokenUris;
  }

  // we want whoever has called the request function, we want them to have their own NFT
  // right now this will happen in two transactions -> first request than fufill
  // if we were to use _safeMint(msg.sender, s_tokenCounter) -> the owner of the NFT will be the chainlink node that fufilled random words
  // we want to create a mapping between requestId and the person who called the requestNFT to
  function requestNft() public payable returns (uint256 requestId) {
    if (msg.value < i_mintFee) {
      revert RandomIpfsNft__NeedMoreEthSent();
    }
    requestId = i_vrfCoordinator.requestRandomWords(
      i_gasLane,
      i_subscriptionId,
      REQUEST_CONFIRMATIONS,
      i_callbackGasLimit,
      NUM_WORDS
    );
    //we'll convert the requestId to the sender's contract so that its not using the subscription contract address as the owwner
    s_requestIdToSender[requestId] = msg.sender;
    emit NftRequested(requestId, msg.sender);
  }

  //Retrieve random number similar to the lottery project

  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
    internal
    override
  {
    //we're retrieving the owner from requestNft
    address dogOwner = s_requestIdToSender[requestId];
    uint256 newTokenId = s_tokenCounter;
    uint256 moddedRng = randomWords[0] % MAX_CHANCE_VALUE; //modding cause we're getting a value between 0-99

    Breed dogBreed = getBreedFromModdedRng(moddedRng);
    //update token counter
    s_tokenCounter += s_tokenCounter;
    //we can now use the _safeMint function to send the token to the new contract minter
    _safeMint(dogOwner, newTokenId);
    //We can use ERC721URIStorage extension function _setTokenURI
    // to assing a picture URI to a tokenID
    //The URI (image) will reflect the dog's Breed.
    _setTokenURI(newTokenId, s_dogTokenUris[uint256(dogBreed)]);
    emit NftMinted(dogBreed, dogOwner);
  }

  //we can use Ownable.sol code within openzepplin that will
  function withdraw() public onlyOwner {
    uint256 amount = address(this).balance;
    (bool success, ) = payable(msg.sender).call{value: amount}("");
    if (!success) {
      revert RandomIpfsNft__TransferFailed();
    }
  }

  function getBreedFromModdedRng(uint256 moddedRng)
    public
    pure
    returns (Breed)
  {
    uint256 cumulativeSum = 0;
    uint256[3] memory chanceArray = getChanceArray();
    for (uint256 i = 0; i < chanceArray.length; i++) {
      if (
        moddedRng >= cumulativeSum && moddedRng < cumulativeSum + chanceArray[i]
      ) {
        return Breed(i);
      }
      cumulativeSum += chanceArray[i];
    }

    //If for some reason we cant get a breed, raise an error
    revert RandomIpfsNft__RangeOutOfBounds();
  }

  // We want to supply a random chance for the dog to be one of the three types
  //we will use this to assing the dog breed to the randomly selected nft
  function getChanceArray() public pure returns (uint256[3] memory) {
    return [10, 30, MAX_CHANCE_VALUE];
    // This reads as:
    // index 0 (pug) -> 10% chance (0-9)
    // index 1 (Shiba)-> 20% chance (10-29)
    // index 2 (St. Bernard)-> 70% chance (30-100)
  }

  function getMintFee() public view returns (uint256) {
    return i_mintFee;
  }

  function getDogTokenUris(uint256 index) public view returns (string memory) {
    return s_dogTokenUris[index];
  }

  function getTokenCounter() public view returns (uint256) {
    return s_tokenCounter;
  }
}
