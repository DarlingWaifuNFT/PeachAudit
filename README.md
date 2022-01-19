# PEACH

**Has 4 entities**:
Owner: will be renounced
Support: for maintenance tasks
Oracle: for financial settings
Game: Will not be affected by taxes

## **Events**:
- Transfer

## **Functions**:
### **ERC20**:
- balanceOf (external view)
- allowance (external view)
- approve (external)
- name (external view)
- symbol (external view)
- decimals (external view)
- totalSupply (external view)
- transfer (external isAllowedTransaction)
- transferFrom (external isAllowedTransaction)

### **Custom**:
- getTransactionLimit (external view)
- setLiquidityExtractionLimit (external onlyOracle)
- approveTransactor (external)

### **Maintenance**:
- renounceOwnership (external onlyOwner)
- setSupport (external onlyOwner)
- setOracle (external onlySupport)
- upgradeStorage (external onlySupport)
- updateCommission(external onlySupport)
- ban (external onlySupport)
- unban (external onlySupport)
- addSwap (external onlySupport)


# PEACH STORAGE

**Has 4 entities:**
Owner: will be renounced
Support: for maintenance tasks
Oracle: for financial settings
Manager: Peach contract, the only address capable of making non-maintenance transactions

## **Events**:
- Transfer
- Approval

## **Functions**:
### **ERC20~ish**:
- balanceOf (external view)
- allowance (external view)
- approve (external onlyManager)
- name (external view)
- symbol (external view)
- decimals (external view)
- totalSupply (external view)
- transfer(external onlyManager)
- transferFrom (external onlyManager)

### **Custom**:
- getCurrentPrice (external)
- getPeach (external)
- getExpenditure (external)

### **Maintenance**:
- upgradePeach (external onlySupport)
- setSupport (external onlyOwner)
- setOracle (external onlySupport)
- setCurrentPrice (external onlyOracle)


**Transfer logic**
1. Invoke `transfer` in Peach
2. Verify if `isAllowedTransaction`.
    1. Require or:
        1. **`amount * price < _getTransactionLimit`**
        2. authorizedTransactor
        3. swaps[sender]
        4. not swaps[destination]
    2. **Require: user is not banned.**
3. Verify `validSender`: msg.sender is the spender.
4. Get commission:
    1. Assign a fixed commission.
    2. If the wallet is buying from an exchange or getting tokens from the game, commission = 0.
    3. If the wallet is selling the tokens in an exchange:
        1. **Require the `time window expenditure + amount * currentPrice < liquidityExtractionLimit`.**
        2. **If amount * currentPrice > maxCashOut, the wallet gets a big commission.**
5. Invoke `transfer` in PeachStorage
6. Require the sender is Peach
7. Require nor the sender nor the destination are the null address
8. Require the sender has funds
9. Subtract the funds from the sender
10. Add the funds minus the commission to the destination
11. Add the commission to the Rewards Pool
12. **Add the transaction amount * currentPrice to the expenditure hourly mapping of the sender.**
13. Emit the Transfer event for the main transfer transaction
14. Emit the Transfer event for the commission transaction

# Considerations:
**The current price is multiplied by 1000 due to the lack of decimals.**

**Every transaction counts towards the limit for liquidity extraction, not just extractions themselves.**

**These functions give percentages as results:**
- Big commission formula (x is total USD):
  ```txt
  f(x) = 60 - (550000 * 10**21) / (x + 10000 * 10**21)
  ```
- Transaction limit calculation:
  ```txt
	f(x) = (3000 * 10**21) / (_balance * currentPrice + 120 * 10**21)
  ```
