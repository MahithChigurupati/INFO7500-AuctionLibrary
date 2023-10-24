## INFO7500 - Vickrey Auction

1. **Seller:**

   - the `createAuction` function, allowing a seller to list a physical item for auction. This function permit the seller to set parameters like `startTime`, `bidPeriod`, `revealPeriod`, and `reservePrice`.
   - The auction begins at the block in which the contract is created.

2. **Bidding:**

   - the `commitBid` function permits interested bidders to commit their bids for an item with the price of their choice. Bidders should send Ether as collateral.bidders can only commit bids after the `startTime` set by the seller has passed and until the start of the `revealPeriod`.

3. **Bid Reveal:**

   - the `revealBid` function. Bidders should be able to reveal their bids during the `revealPeriod` using the `bidValue` and a `nonce`. bids cant be submitted after this period.

4. **Auction Completion:**

   - the `endAuction` function, allowing the auction to be completed after all bidders have revealed their bids. winning bidder is determined, the asset is transferred, collateral is managed.

5. **Withdraw Collateral:**
   - Implement the `withdrawCollateral` function, enabling non-winning bidders to withdraw their bid collateral after the auction ends.

## instructions to run the code

`forge build` - to generate build

`forge test` - to run unit test
