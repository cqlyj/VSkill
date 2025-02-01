### Installation

1. Clone the repository:
   ```
   git clone https://github.com/cqlyj/VSkill
   ```
2. Navigate to the project directory:
   ```
   cd VSkill
   ```
3. Install dependencies:
   ```
   make install
   ```
4. Build the project:
   ```
   make build
   ```

### To get the same issue as I do:

1. Set up your environment variables:

```
cp .env.example .env
```

Edit `.env` and add your RPC URL and your burner account address.

2. Go to the file `script/interactions/AutomationInteractions/SyedRegisterUpkeep.s.sol` and change the `ADMIN_ADDRESS` to your burner account address.

3. Run the command below:

```bash
 make syed-register-upkeep NETWORK=Amoy
```
