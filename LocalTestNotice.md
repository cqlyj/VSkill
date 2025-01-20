Notice that if trying to deploy the `Distibution` contract on anvil testnet, it will revert due to the issue the `block.number` is set to 0 in anvil and it will break the rule in contract `SubscriptionAPI` as following:

```javascript

function createSubscription() external override nonReentrant returns (uint256 subId) {
    uint64 currentSubNonce = s_currentSubNonce;
    subId = uint256(
@>    keccak256(abi.encodePacked(msg.sender, blockhash(block.number - 1), address(this), currentSubNonce))
    );
    s_currentSubNonce = currentSubNonce + 1;
    address[] memory consumers = new address[](0);
    s_subscriptions[subId] = Subscription({balance: 0, nativeBalance: 0, reqCount: 0});
    s_subscriptionConfigs[subId] = SubscriptionConfig({
      owner: msg.sender,
      requestedOwner: address(0),
      consumers: consumers
    });
    s_subIds.add(subId);

    emit SubscriptionCreated(subId, msg.sender);
    return subId;
  }

```

This line of code will cause the `blockhash(block.number - 1)` to underflow and thus revert the transaction. This is not a bug in the contract, but a bug in the testnet.

Whenever test on anvil, we need to modify this line of code to `blockhash(block.number)` to make it work.
