// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BasicVickreyAuction} from "../src/BasicVickreyAuction.sol";

contract BasicVickreyAuctionTest is Test {
    BasicVickreyAuction auction;

    address OWNER = makeAddr("owner");
    address USER = makeAddr("user");
    address WINNER = makeAddr("winner");

    uint256 constant AUCTION_ID = 1;
    uint256 constant BID_VALUE = 1 ether;

    uint256 constant TOKEN_ID = 1;
    uint256 constant BID_START = 0;
    uint256 constant BID_END = 2 minutes;
    uint256 constant REVEAL_START = 2 minutes;
    uint256 constant RESERVE_PRICE = ONE_ETH;

    uint256 constant UNREVEALED_BIDS = 0;
    uint256 constant HIGHEST_BID = 0;
    uint256 constant SECOND_HIGHEST_BID = 0;

    bytes32 constant NONCE = 0x0000000000000000000000000000000000000000000000000000000000000000;

    uint256 constant ONE_ETH = 1 ether;
    uint256 constant TWO_ETH = 2 ether;
    uint256 constant THREE_ETH = 3 ether;

    function setUp() external {
        auction = new BasicVickreyAuction();
    }

    function testCreateAuction() external {
        BasicVickreyAuction.Auction memory expectedAuction = BasicVickreyAuction.Auction({
            seller: payable(OWNER),
            bidStart: block.timestamp,
            bidEnd: uint256(block.timestamp + 2 minutes),
            revealEnd: uint256(block.timestamp + 4 minutes),
            unrevealedBids: 0,
            highestBid: RESERVE_PRICE,
            secondHighestBid: RESERVE_PRICE,
            highestBidder: payable(address(0)),
            index: 1
        });
        BasicVickreyAuction.Auction memory actualAuction = createAuction(TOKEN_ID);
        assertAuctionsEqual(actualAuction, expectedAuction);
    }

    function createAuction(uint256 tokenId) private returns (BasicVickreyAuction.Auction memory a) {
        hoax(OWNER);
        auction.createAuction(tokenId, BID_START, BID_END, REVEAL_START, RESERVE_PRICE);
        return auction.getAuction(tokenId);
    }

    function assertAuctionsEqual(
        BasicVickreyAuction.Auction memory actualAuction,
        BasicVickreyAuction.Auction memory expectedAuction
    ) public {
        assertEq(actualAuction.seller, expectedAuction.seller);
        assertEq(actualAuction.bidStart, expectedAuction.bidStart);
        assertEq(actualAuction.bidEnd, expectedAuction.bidEnd);
        assertEq(actualAuction.revealEnd, expectedAuction.revealEnd);
        assertEq(actualAuction.unrevealedBids, expectedAuction.unrevealedBids);
        assertEq(actualAuction.highestBid, expectedAuction.highestBid);
        assertEq(actualAuction.secondHighestBid, expectedAuction.secondHighestBid);
        assertEq(actualAuction.highestBidder, expectedAuction.highestBidder);
        assertEq(actualAuction.index, expectedAuction.index);
    }

    function testCommitBid() external {
        createAuction(TOKEN_ID);
        // skip(1 hours + 30 minutes);
        bytes20 commitment = commitBid(TOKEN_ID, USER, TWO_ETH, NONCE);
        assertBid(1, USER, commitment, 1);
    }

    function commitBid(uint256 tokenId, address from, uint256 bidValue, bytes32 nonce)
        private
        returns (bytes20 commitment)
    {
        commitment = bytes20(keccak256(abi.encode(nonce, bidValue, tokenId, AUCTION_ID)));
        hoax(from);
        auction.commitBid{value: bidValue}(tokenId, commitment);
    }

    function assertBid(uint256 auctionIndex, address bidder, bytes20 commitment, uint256 unrevealedBids) private {
        (bytes20 storedCommitment,) = auction.bids(TOKEN_ID, auctionIndex, bidder);
        assertEq(storedCommitment, commitment, "commitment");
        assertEq(auction.getAuction(1).unrevealedBids, unrevealedBids, "unrevealedBids");
    }

    function testRevealBid() external {
        BasicVickreyAuction.Auction memory expectedState = createAuction(TOKEN_ID);
        // skip(1 hours + 30 minutes);

        commitBid(TOKEN_ID, USER, TWO_ETH, NONCE);
        skip(3 minutes);
        hoax(USER);
        auction.revealBid(TOKEN_ID, TWO_ETH, NONCE);

        expectedState.unrevealedBids = 0; // the only bid was revealed
        expectedState.highestBid = TWO_ETH;
        expectedState.highestBidder = payable(USER);
        assertAuctionsEqual(auction.getAuction(1), expectedState);
    }

    function testEndAuctionAfterRevealPeriod() external {
        createAuction(TOKEN_ID);
        skip(2 minutes);
        // uint256 collateral = 2 * ONE_ETH;
        commitBid(TOKEN_ID, USER, TWO_ETH, NONCE);
        // bytes20 userCommitment = commitBid(TOKEN_ID, USER, TWO_ETH, NONCE);
        skip(2 minutes);
        hoax(USER);
        auction.revealBid(TOKEN_ID, TWO_ETH, NONCE);
        skip(3 minutes);
        uint256 ownerBalanceBefore = OWNER.balance;
        auction.endAuction(1);
        assertEq(OWNER.balance, ownerBalanceBefore + ONE_ETH);
    }
}
