## zkSync Local Node Instructions

### Prerequisites

- [foundry-zksync](https://github.com/matter-labs/foundry-zksync)

  - You'll know you've done it right if you can run `forge --version` and you see a response like `forge 0.0.2 (b513e39 2024-10-18T00:25:11.767467870Z)`
  - If you're unsure whether you're using vanilla or zkSync, note that for zkSync it is `0.0.2`, and for vanilla it is `0.2.0` (these are versions which may change over time).

- [docker](https://docs.docker.com/engine/install/)
  - You'll know you've done it right if you can run `docker --version` and you see a response like `Docker version 27.3.1, build ce12230`
- [nodejs & npm](https://nodejs.org/en/download/package-manager)
  - You'll know you've done it right if you can run `node --version` and you see a response like `v20.12.2`
  - Additionally, you'll know you've done it right if you can run `npm --version` and you see a response like `10.5.0`

### Run a local zkSync test node

1. Setup the config

```bash
npx zksync-cli dev config
```

Select `in-memory node` and no additional plugins.

2. Run the node

```bash
npx zksync-cli dev start
```

If you get an error like: `Command exited with code 1: Error response from daemon: dial unix docker.raw.sock: connect: connection refused`, this means docker is not running.

### Deploy to zkSync

```bash
forge create src/staking/Staking.sol:Staking --rpc-url $ZKSYNC_LOCAL_RPC_URL --private-key $ZKSYNC_LOCAL_PRIVATE_KEY --legacy --zksync --constructor-args $(CONSTRUCTOR_ARGS)
```

or

```bash
forge script script/staking/DeployStaking.s.sol:DeployStaking --rpc-url $ZKSYNC_LOCAL_RPC_URL --private-key $ZKSYNC_LOCAL_PRIVATE_KEY --legacy --zksync --broadcast -vvvv
```

However, you may fail to run the scripts and if that happens, just run theta `create` command.
