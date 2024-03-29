// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FakeNFTMarketplace {
    /// @dev Maintain a mapping of 'Fake' TokenID to Owner Addresses
    mapping(uint256 => address) public tokens;

    /// @dev Set the purchase price for each Fake NFT
    uint256 nftPrice = 0.1 ether;

    /// @dev purchase() accepts ETH and marks the owner of the given tokenID as caller address
    /// @param _tokenId - the 'fake' NFT token Id to purchase
    function purchase(uint256 _tokenId) external payable {
        require(msg.value == nftPrice, "This NFT is 0.1 ether");
        tokens[_tokenId] = msg.sender;
    }

    /// @dev getPrice() returns the price of one NFT
    function getPrice() external view returns (uint256) {
        return nftPrice;
    }

    /// @dev available() checks whether the given tokenId has already been sold or not
    /// @param _tokenId - the tokenId to check for
    function available(uint256 _tokenId) public view returns (bool) {
        //address(0) is the default value for addresses in solidity
        if (tokens[_tokenId] == address(0)) {
            return true;
        }
        return false;
    }
}
