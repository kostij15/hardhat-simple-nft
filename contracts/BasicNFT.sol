// SPDX License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

pragma solidity ^0.8.7;

//we'll be using open zepplin contracts
contract BasicNFT is ERC721 {
  //_safeMint takes a parameter tokenId, which references each NFT token's unique id
  //we will need to add a private variable that represents tokenId
  uint256 private s_tokenCounter;

  //for our simple contract we're having a uri
  //The image current has ipfs.io. WE DO NOT WANT THAT GOING FORWARD SINCE IF IT GOES DOWN ITS OVERRRRRRR-> SIMPLY FOR THE EXAMPLE
  string public constant TOKEN_URI =
    "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";

  constructor() ERC721("Dogie", "DOG") {
    s_tokenCounter = 0;
  }

  function mintNft() public returns (uint256) {
    _safeMint(msg.sender, s_tokenCounter);
    s_tokenCounter = s_tokenCounter + 1;
    return s_tokenCounter;
  }

  function tokenURI(
    uint256 /*tokenId*/ //The original contract takes a tokenId however since it is only one for this contract we won't be using it here
  ) public view override returns (string memory) {
    return TOKEN_URI;
  }

  function getTokenCounter() public view returns (uint256) {
    return s_tokenCounter;
  }
}
