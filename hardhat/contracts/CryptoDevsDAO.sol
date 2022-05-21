// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * Interface for FakeNFTMarketplace
 */

interface IFakeNFTMarketplace {
    /// @dev getPrice() returns the price of an NFT from the marketplace
    /// @return Returns the price in Wei for an NFT
    function getPrice() external view returns (uint256);

    /// @dev available() returns whether or not the _tokenID has been purchased
    /// @return Returns a boolean, available if true
    function available(uint256 _tokenId) external view returns (bool);

    /// @dev purchase() purchases an NFT from the marketplace
    /// @param _tokenId is the NFT tokenID to purchase
    function purchase(uint256 _tokenId) external payable;
}

interface ICryptoDevsNFT {
    /// @dev balanceOf returns the number of NFTs owned by a given address
    /// @param owner is the address to fetch the number of NFTs from
    /// @return Returns the no. of tokens in 'owner's' account
    function balanceOf(address owner) external view returns (uint256);

    /// @dev tokenOfOwnerByIndex returns token ID owned by an address at given index
    /// @param owner is the address to fetch the NFT token IDs from
    /// @return Returns the tokenID
    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        returns (uint256);
}

contract CryptoDevsDAO is Ownable {
    struct Proposal {
        //the tokenId of the NFT to purchase from marketplace
        uint256 nftTokenId;
        //UNIX timestamp until which proposal is active
        uint256 deadline;
        //no. of yes votes
        uint256 yesVotes;
        //no. of no votes
        uint256 noVotes;
        //whether or not this proposal has been executed - can't be executed before deadline
        bool executed;
        //mapping of CryptoDevNFT tokenIDs to booleans, indicating if NFT has been used to vote
        mapping(uint256 => bool) voters;
    }

    //mapping of prposalID to proposal
    mapping(uint256 => Proposal) public proposals;

    //no. of proposals created
    uint256 public numProposals;

    //initializing contracts we are calling from
    IFakeNFTMarketplace nftMarketplace;
    ICryptoDevsNFT cryptoDevsNFT;

    //payable constructor that initializes the contract instances
    //payable allows constructor to accept an ETH deposit when deployed
    constructor(address _nftMarketplace, address _cryptoDevsNFT) payable {
        nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
        cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
    }

    //this modifier only allows a CryptoDev holder to call a modified function
    modifier nftHolderOnly() {
        require(
            cryptoDevsNFT.balanceOf(msg.sender) > 0,
            "NOT A MEMBER OF THIS DAO"
        );
        _;
    }

    /// @dev createProposal allows an NFT holder to create a new proposal in the DAO
    /// @param _nftTokenId is the token ID to be purchased from the marketplace
    /// @return Returns the proposal index for newly created proposal
    function createProposal(uint256 _nftTokenId)
        external
        nftHolderOnly
        returns (uint256)
    {
        require(
            nftMarketplace.available(_nftTokenId),
            "That NFT is not for sale."
        );
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId = _nftTokenId;

        //Set the proposal's voting deadline to be curr time + 5 mins
        proposal.deadline = block.timestamp + 5 minutes;

        numProposals++;

        //returning the index of the new proposal
        return numProposals - 1;
    }

    //Modifier that only allows function to be called if given proposal's deadline hasn't passed
    modifier activeProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline > block.timestamp,
            "Deadline has passed for this proposal"
        );
        _;
    }

    //YES = 0, NO = 1
    enum Vote {
        YES,
        NO
    }

    /// @dev voteOnProposal allows NFT holder to case vote on active proposal
    /// @param proposalIndex is the index of the proposal on the proposals array
    /// @param vote is the type of vote they want to cast

    function voteOnProposal(uint256 proposalIndex, Vote vote)
        external
        nftHolderOnly
        activeProposalOnly(proposalIndex)
    {
        Proposal storage proposal = proposals[proposalIndex];

        uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        uint256 numVotes = 0;

        //Calculating how many NFTs are owned by the voter
        //that haven't already been used for voting for this proposal

        for (uint256 i = 0; i < voterNFTBalance; i++) {
            uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
            if (proposal.voters[tokenId] == false) {
                numVotes++;
                proposal.voters[tokenId] = true;
            }
        }

        require(numVotes > 0, "Already voted.");

        if (vote == Vote.YES) {
            proposal.yesVotes += numVotes;
        } else {
            proposal.noVotes += numVotes;
        }
    }

    //Modifier that only allows a function to be called if the proposal's deadline has exceeded
    //and  proposal hasn't yet been executed

    modifier inactiveProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline <= block.timestamp,
            "Deadline has NOT passed"
        );

        require(
            proposals[proposalIndex].executed == false,
            "Proposal has been executed"
        );
        _;
    }

    /// @dev executeProposal allows any CryptoDevsNFT holder to execute a proposal the deadline
    /// @param proposalIndex - the index of the proposal to execute in the proposal's array
    function executeProposal(uint256 proposalIndex)
        external
        nftHolderOnly
        inactiveProposalOnly(proposalIndex)
    {
        Proposal storage proposal = proposals[proposalIndex];

        //If proposal has more yes votes than no votes, purchase the NFT from the marketplace
        if (proposal.yesVotes > proposal.noVotes) {
            uint256 nftPrice = nftMarketplace.getPrice();

            //checking the balance of the contract
            require(
                address(this).balance >= nftPrice,
                "Not enough funds in the treasury"
            );
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }
        proposal.executed = true;
    }

    /// @dev withdrawEther allows contract owner to withdraw from the contract
    function withdrawEther() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    //these functions allow the contract to accept ETH deposits without a function being called
    //empty calldata
    receive() external payable {}

    //if no other function matches
    fallback() external payable {}
}
