// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NFTVickreyAuction_ERC20Bids {
    struct Auction {
        address erc20;
        address seller;
        uint256 bidStart;
        uint256 bidEnd;
        uint256 revealEnd;
        uint256 unrevealedBids;
        uint256 highestBid;
        uint256 secondHighestBid;
        address highestBidder;
        uint256 index;
    }

    struct Bid {
        bytes20 commitment;
        uint256 collateral;
    }

    mapping(address => mapping(uint256 => Auction)) public auctions;

    mapping(
        address // ERC721 token contract
            => mapping(
                uint256 //
                        // Auction index
                    => mapping(
                        uint256
                            => mapping(
                                address // Bidder
                                    => Bid
                            )
                    )
            )
    ) public bids;

    function calculateHash(
        bytes32 nonce,
        uint256 bidValue,
        address tokenContract,
        uint256 tokenId,
        uint256 auctionIndex
    ) external pure returns (bytes20) {
        bytes32 hash = keccak256(abi.encode(nonce, bidValue, tokenContract, tokenId, auctionIndex));
        bytes20 result = bytes20(hash);

        return result;
    }

    function createAuction(
        address tokenContract,
        uint256 tokenId,
        address erc20,
        uint256 bidStart,
        uint256 bidPeriod,
        uint256 revealPeriod,
        uint256 reservePrice
    ) external {
        Auction storage auction = auctions[tokenContract][tokenId];

        require(bidStart == 0, "Bid start time must be initialized to 0");
        bidStart = uint256(block.timestamp);

        require(bidStart >= block.timestamp, "Invalid start time");
        require(bidPeriod >= 1 minutes, "Bid period must be at least 1 minute");
        require(revealPeriod >= 1 minutes, "Reveal period must be at least 1 minute");

        auction.erc20 = erc20;
        auction.seller = msg.sender;
        auction.bidStart = bidStart;
        auction.bidEnd = bidStart + bidPeriod;
        auction.revealEnd = bidStart + bidPeriod + revealPeriod;
        auction.unrevealedBids = 0;
        auction.highestBid = reservePrice;
        auction.secondHighestBid = reservePrice;
        auction.highestBidder = address(0);
        auction.index += 1;

        ERC721(tokenContract).transferFrom(msg.sender, address(this), tokenId);
    }

    function commitBid(address tokenContract, uint256 tokenId, bytes20 commitment, uint256 tokensERC20) external {
        if (commitment == bytes20(0)) {
            revert("zero commitment");
        }

        Auction storage auction = auctions[tokenContract][tokenId];
        address tokensERC20Contract = auction.erc20;
        if (block.timestamp < auction.bidStart || block.timestamp > auction.bidEnd) {
            revert("Not in bid period");
        }

        uint256 auctionIndex = auction.index;
        Bid storage bid = bids[tokenContract][tokenId][auctionIndex][msg.sender];
        if (bid.commitment == bytes20(0)) {
            auction.unrevealedBids++;
        }
        ERC20(tokensERC20Contract).transferFrom(msg.sender, address(this), tokensERC20);

        bid.commitment = commitment;
        if (tokensERC20 != 0) {
            bid.collateral += uint256(tokensERC20);
        }
    }

    function revealBid(address tokenContract, uint256 tokenId, uint256 bidValue, bytes32 nonce) external {
        Auction storage auction = auctions[tokenContract][tokenId];
        address tokensERC20Contract = auction.erc20;

        if (block.timestamp <= auction.bidEnd || block.timestamp > auction.revealEnd) {
            revert("not in reveal period error");
        }

        uint256 auctionIndex = auction.index;
        Bid storage bid = bids[tokenContract][tokenId][auctionIndex][msg.sender];

        bytes20 bidHash = bytes20(keccak256(abi.encode(nonce, bidValue, tokenContract, tokenId, auctionIndex)));
        if (bidHash != bid.commitment) {
            revert("invalid opening");
        } else {
            // Mark commitment as open
            bid.commitment = bytes20(0);
            auction.unrevealedBids--;
        }

        uint256 collateral = bid.collateral;
        if (collateral < bidValue) {
            bid.collateral = 0;
            ERC20(tokensERC20Contract).transfer(msg.sender, collateral);
        } else {
            uint256 currentHighestBid = auction.highestBid;
            if (bidValue > currentHighestBid) {
                auction.highestBid = bidValue;
                auction.secondHighestBid = currentHighestBid;
                auction.highestBidder = msg.sender;
            } else {
                if (bidValue > auction.secondHighestBid) {
                    auction.secondHighestBid = bidValue;
                }
                bid.collateral = 0;
                ERC20(tokensERC20Contract).transfer(msg.sender, collateral);
            }
        }
    }

    function endAuction(address tokenContract, uint256 tokenId) external {
        Auction storage auction = auctions[tokenContract][tokenId];
        address tokensERC20Contract = auction.erc20;
        if (auction.index == 0) {
            revert("invalid auction index");
        }

        if (block.timestamp <= auction.bidEnd) {
            revert("bid period ongoing");
        } else if (block.timestamp <= auction.revealEnd) {
            if (auction.unrevealedBids != 0) {
                revert("reveal period ongoing");
            }
        }

        address highestBidder = auction.highestBidder;
        if (highestBidder == address(0)) {
            ERC721(tokenContract).safeTransferFrom(address(this), auction.seller, tokenId);
        } else {
            ERC721(tokenContract).safeTransferFrom(address(this), highestBidder, tokenId);
            uint256 secondHighestBid = auction.secondHighestBid;
            ERC20(tokensERC20Contract).transfer(auction.seller, secondHighestBid);

            Bid storage bid = bids[tokenContract][tokenId][auction.index][highestBidder];
            uint256 collateral = bid.collateral;
            bid.collateral = 0;
            if (collateral - secondHighestBid != 0) {
                ERC20(tokensERC20Contract).transfer(highestBidder, collateral - secondHighestBid);
            }
        }
    }

    function withdrawCollateral(address tokenContract, uint256 tokenId, uint256 auctionIndex) external {
        Auction storage auction = auctions[tokenContract][tokenId];
        address tokensERC20Contract = auction.erc20;
        uint256 currentAuctionIndex = auction.index;
        if (auctionIndex > currentAuctionIndex) {
            revert("invalid auction index");
        }

        Bid storage bid = bids[tokenContract][tokenId][auctionIndex][msg.sender];
        if (bid.commitment != bytes20(0)) {
            revert("unrevealed bid");
        }

        if (auctionIndex == currentAuctionIndex) {
            if (msg.sender == auction.highestBidder) {
                revert("cannot withdraw");
            }
        }
        uint256 collateral = bid.collateral;
        bid.collateral = 0;
        ERC20(tokensERC20Contract).transfer(msg.sender, collateral);
    }

    function getAuction(address tokenContract, uint256 tokenId) external view returns (Auction memory auction) {
        return auctions[tokenContract][tokenId];
    }
}
