// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {NFTVickreyAuction_ERC20Bids} from "../src/NFTVickreyAuction_ERC20Bids.sol";
import {ERC721Token} from "../src/ERC721Token.sol";
import {ERC20Token} from "../src/ERC20Token.sol";

contract NFTVickreyAuction_ERC20BidsTest is Test {
    NFTVickreyAuction_ERC20Bids auction;
    ERC20Token erc20token;
    ERC721Token erc721token;

    address OWNER = makeAddr("owner");
    address USER = makeAddr("user");
    address WINNER = makeAddr("winner");

    uint256 constant AUCTION_ID = 1;
    uint256 constant BID_VALUE = 1 * 10 ** 18;

    uint256 constant TOKEN_ID = 0;
    uint256 constant BID_START = 0;
    uint256 constant BID_END = 2 minutes;
    uint256 constant REVEAL_START = 2 minutes;
    uint256 constant RESERVE_PRICE = ONE_erc20;

    uint256 constant UNREVEALED_BIDS = 0;
    uint256 constant HIGHEST_BID = 0;
    uint256 constant SECOND_HIGHEST_BID = 0;

    bytes32 constant NONCE = 0x0000000000000000000000000000000000000000000000000000000000000000;

    uint256 constant ONE_erc20 = 1 * 10 ** 18;
    uint256 constant TWO_erc20 = 2 * 10 ** 18;
    uint256 constant THREE_erc20 = 3 * 10 ** 18;

    function setUp() external {
        auction = new NFTVickreyAuction_ERC20Bids();
        erc20token = new ERC20Token();
        erc721token = new ERC721Token();

        erc20token.mint(USER, 100 * 10 ** 18);

        erc721token.mint(OWNER);

        hoax(OWNER);
        erc721token.approve(address(auction), 0);

        hoax(USER);
        erc20token.approve(address(auction), 100 * 10 ** 18);
    }

    function testCreateAuction() external {
        NFTVickreyAuction_ERC20Bids.Auction memory expectedAuction = NFTVickreyAuction_ERC20Bids.Auction({
            erc20: address(erc20token),
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
        NFTVickreyAuction_ERC20Bids.Auction memory actualAuction = createAuction(TOKEN_ID);
        assertAuctionsEqual(actualAuction, expectedAuction);
    }

    function createAuction(uint256 tokenId) private returns (NFTVickreyAuction_ERC20Bids.Auction memory a) {
        hoax(OWNER);
        auction.createAuction(
            address(erc721token), tokenId, address(erc20token), BID_START, BID_END, REVEAL_START, RESERVE_PRICE
        );
        return auction.getAuction(address(erc721token), tokenId);
    }

    function assertAuctionsEqual(
        NFTVickreyAuction_ERC20Bids.Auction memory actualAuction,
        NFTVickreyAuction_ERC20Bids.Auction memory expectedAuction
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

        bytes20 commitment = commitBid(TOKEN_ID, TWO_erc20, USER, TWO_erc20, NONCE);

        assertBid(1, USER, commitment, 0);
    }

    function commitBid(uint256 tokenId, uint256 tokens, address from, uint256 bidValue, bytes32 nonce)
        private
        returns (bytes20 commitment)
    {
        commitment = bytes20(keccak256(abi.encode(nonce, bidValue, address(erc721token), tokenId, AUCTION_ID)));
        hoax(from);
        auction.commitBid(address(erc721token), tokenId, commitment, tokens);
    }

    function assertBid(uint256 auctionIndex, address bidder, bytes20 commitment, uint256 unrevealedBids) private {
        (bytes20 storedCommitment,) = auction.bids(address(erc721token), TOKEN_ID, auctionIndex, bidder);
        assertEq(storedCommitment, commitment, "commitment");
        assertEq(auction.getAuction(address(erc721token), 1).unrevealedBids, unrevealedBids, "unrevealedBids");
    }

    function testRevealBid() external {
        NFTVickreyAuction_ERC20Bids.Auction memory expectedState = createAuction(TOKEN_ID);
        // skip(1 hours + 30 minutes);

        commitBid(TOKEN_ID, TWO_erc20, USER, TWO_erc20, NONCE);
        skip(3 minutes);

        hoax(USER);
        auction.revealBid(address(erc721token), TOKEN_ID, TWO_erc20, NONCE);

        expectedState.unrevealedBids = 0; // the only bid was revealed
        expectedState.highestBid = TWO_erc20;
        expectedState.highestBidder = payable(USER);
        assertAuctionsEqual(auction.getAuction(address(erc721token), 0), expectedState);
    }

    function testEndAuctionAfterRevealPeriod() external {
        createAuction(TOKEN_ID);
        skip(2 minutes);

        commitBid(TOKEN_ID, TWO_erc20, USER, TWO_erc20, NONCE);
        skip(2 minutes);
        hoax(USER);
        auction.revealBid(address(erc721token), TOKEN_ID, TWO_erc20, NONCE);
        skip(3 minutes);
        uint256 ownerBalanceBefore = erc20token.balanceOf(OWNER);
        auction.endAuction(address(erc721token), 0);
        assertEq(erc20token.balanceOf(OWNER), ownerBalanceBefore + ONE_erc20);
    }
}
