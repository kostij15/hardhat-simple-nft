//DynamicSvgNft.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "base64-sol/base64.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DynamicSvgNft is ERC721 {
  //mint
  //store our SVG somewhere
  // some logic to say "Show X Image" or "Show Y Image" -> do this via tokenUri

  uint256 private s_tokenCounter;
  string private i_lowImageURI;
  string private i_highImageURI;
  string private constant base64EncodedSvgPrefix = "data:image/svg+xml;base64,";
  AggregatorV3Interface internal immutable i_priceFeed;

  mapping(uint256 => int256) public s_tokenIdToHighValue;

  event CreatedNFT(uint256 indexed tokenId, int256 highValue);

  constructor(
    address priceFeed,
    string memory lowSvg,
    string memory highSvg
  ) ERC721("Dynamic SVG NFT", "DSN") {
    s_tokenCounter = 0;
    i_lowImageURI = svgToImageURI(lowSvg);
    i_highImageURI = svgToImageURI(highSvg);
    i_priceFeed = AggregatorV3Interface(priceFeed);
  }

  //to convert the svg to image on-chain
  //we will use base64 encoding
  function svgToImageURI(string memory svg)
    public
    pure
    returns (string memory)
  {
    //
    string memory svgBase64Encoded = Base64.encode(
      bytes(string(abi.encodePacked(svg)))
    );
    return string(abi.encodePacked(base64EncodedSvgPrefix, svgBase64Encoded));
  }

  // THis time it will be a free NFT
  function mintNft(int256 highValue) public {
    s_tokenIdToHighValue[s_tokenCounter] = highValue;
    s_tokenCounter = s_tokenCounter + 1;
    _safeMint(msg.sender, s_tokenCounter);

    emit CreatedNFT(s_tokenCounter, highValue);
  }

  function _baseURI() internal pure override returns (string memory) {
    return "data:application/json;base64";
  }

  //We can base64 encode our ipfs json after we base64 encode svg
  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(_exists(tokenId), "URI for nonexistent token");

    (, int256 price, , , ) = i_priceFeed.latestRoundData();
    string memory imageURI = i_lowImageURI;
    if (price >= s_tokenIdToHighValue[tokenId]) {
      imageURI = i_highImageURI;
    }

    //prefix for base64 json is
    //    data:application/json;base64

    return
      string(
        abi.encodePacked(
          _baseURI(),
          Base64.encode(
            bytes(
              abi.encodePacked(
                '{"name":"',
                name(), // You can add whatever name here
                '", "description":"An NFT that changes based on the Chainlink Feed", ',
                '"attributes": [{"trait_type": "coolness", "value": 100}], "image":"',
                imageURI,
                '"}'
              )
            )
          )
        )
      );
  }

  function getPriceFeed() public view returns (AggregatorV3Interface) {
    return i_priceFeed;
  }

  function getLowUri() public view returns (string memory) {
    return i_lowImageURI;
  }

  function getHighUri() public view returns (string memory) {
    return i_highImageURI;
  }

  function getTokenCounter() public view returns (uint256) {
    return s_tokenCounter;
  }
}
