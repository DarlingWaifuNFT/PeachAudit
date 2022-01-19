// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.16 <0.9.0;

import "./PeachStorage.sol";
import "./support/safemath.sol";

contract PeachMathematician {
    using SafeMath for uint256;

    /**
    @dev
    - This contract holds the logic for mathematical calculations not built into Solidity
    - **Random number calculations shall not be done here**.
    */
    event Print(string msg);

    function getBigCommission(uint256 x) internal pure returns (uint256) {
        // Returns a percentage
        return 60 - (550000 * 10**21) / (x + 10000 * 10**21);
    }
}

contract ProxiedStorage is PeachMathematician {
    // Token parameters
    string _name = "DW Peach";
    string _symbol = "PEACH";
    uint8 _decimals = 18;

    address internal owner = msg.sender;
    address internal game = address(0);
    address internal peachStorageAddress =
        0x1Faf80b0812e01692308Fc416E408e2460ED9AdE;
    address internal rewardsPoolv2 = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
    address internal proxy;
    address internal support;
    address internal oracle;
    uint256 internal maxCashout = 100 * 10**_decimals;
    uint256 internal liquidityExtractionLimit; // 21 decimals
    uint256 internal fixedCommission = 5;
    mapping(address => bool) internal authorizedTransactors;
    mapping(address => bool) internal swaps;
    mapping(address => bool) internal banList;
    PeachStorage peachStorage = PeachStorage(peachStorage);

    event Transfer(address indexed from, address indexed to, uint256 amount);

    // Get the balance of any wallet
    function balanceOf(address _target) external view returns (uint256) {
        return peachStorage.balanceOf(_target);
    }

    function _balanceOf(address _target) internal view returns (uint256) {
        return peachStorage.balanceOf(_target);
    }

    // Get the allowance of a wallet
    function allowance(address _owner, address _spender)
        external
        view
        returns (uint256)
    {
        return peachStorage.allowance(_owner, _spender);
    }

    // Approve the allowance for a wallet
    function approve(address _spender, uint256 _amount)
        external
        returns (bool)
    {
        return peachStorage.approve(msg.sender, _spender, _amount);
    }

    // Transfer from a wallet A to a wallet B
    function _safeTransferFrom(
        address _from,
        address _spender,
        address _to,
        uint256 _amount
    ) internal {
        uint256 _commission = _getCommission(_from, _to, _amount);
        peachStorage.transferFrom(_from, _spender, _to, _amount, _commission);
        emit Transfer(_from, _to, _amount - _commission);
        if (_commission != 0) emit Transfer(_from, rewardsPoolv2, _commission);
    }

    function _getTransactionLimit(address _target)
        internal
        view
        returns (uint256)
    {
        uint256 _balance = _balanceOf(_target);
        // This is a percentage
        uint256 limit = (3000 * 10**(_decimals + 3)) /
            (_balance * peachStorage.getCurrentPrice() + 120 * 10**(_decimals + 3));
        return (limit * _balance) / 100;
    }

    function getTransactionLimit() external view returns (uint256) {
        return _getTransactionLimit(msg.sender);
    }

    function _getCommission(
        address _from,
        address _to,
        uint256 _amount
    ) internal view returns (uint256) {
        uint256 _commission = fixedCommission;
        if (swaps[_from] || _from == game) {
            // User is purchasing tokens
            _commission = 0;
        } else if (swaps[_to]) {
            uint256 _expenditure = peachStorage.getExpenditure(_from, 24);
            uint256 _value = _amount * peachStorage.getCurrentPrice();
            uint256 _expense = _expenditure + _value;
            require(
                _expense <= liquidityExtractionLimit,
                "24h window liquidity extraction limit reached."
            );
            // User is selling tokens
            if (_value > maxCashout) {
                _commission = getBigCommission(_value);
            }
        }
        return ((_commission * _amount) / 100);
    }
}

contract Decorated is ProxiedStorage {
    modifier validSender(address from) {
        require(from == msg.sender, "Not the right sender");
        _;
    }

    modifier isntBroken(uint256 quantity, uint256 balance) {
        require(quantity <= balance, "Not enough funds");
        _;
    }

    modifier onlyProxy() {
        require(msg.sender == proxy, "You are not the proxy.");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner.");
        _;
    }

    modifier onlySupport() {
        require(msg.sender == support, "You are not the support.");
        _;
    }

    modifier onlyOracle() {
        require(msg.sender == oracle, "You are not the oracle.");
        _;
    }

    modifier isAllowedTransaction(address destination, uint256 amount, uint256 balance) {
        bool limitCondition = amount * peachStorage.getCurrentPrice() <=
            _getTransactionLimit(msg.sender);
        require(
            authorizedTransactors[msg.sender] ||
                swaps[msg.sender] ||
                !swaps[destination] ||
                limitCondition,
            "This transaction exceeds your limit. You need to authorize it first."
        );
        emit Print("The transaction is within limits.");
        require(
            !banList[msg.sender],
            "You are banned. You may get in touch with the development team to address the issue."
        );
        emit Print("You are not banned, OK.");
        _;
    }
}

contract Peach is PeachMathematician, Decorated {
    address liquidityPool;
    address bnbLiquidityPool;

    constructor() {}

    // Set the support address. Maintainance tasks only
    function setSupport(address _support) external onlyOwner {
        support = _support;
    }

    // Set the oracle address. Financial tasks only
    function setOracle(address _oracle) external onlySupport {
        oracle = _oracle;
    }

    // Upgrade Peach balances. Try not to migrate balances, it could be expensive.
    function upgradeStorage(address _newStorage) external onlySupport {
        peachStorageAddress = _newStorage;
        peachStorage = PeachStorage(peachStorageAddress);
    }

    // Upgrade base commission
    function updateCommission(uint256 _commission) external onlySupport {
        fixedCommission = _commission;
    }

    // Ban a wallet
    function ban(address _target) external onlySupport {
        banList[_target] = true;
    }

    // Unban a wallet
    function unban(address _target) external onlySupport {
        banList[_target] = false;
    }

    // Token information functions for Metamask detection
    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view returns (uint256) {
        return peachStorage.totalSupply();
    }

    // Add a lp address to avoid commissions in outgoing transfers
    function addSwap(address _swap) external onlySupport {
        swaps[_swap] = true;
    }

    function setLiquidityExtractionLimit(uint256 _newLimit)
        external
        onlyOracle
    {
        liquidityExtractionLimit = _newLimit;
    }

    //////////////////////////////////
    /////////// Actual ERC20 functions
    //////////////////////////////////
    // Custom transfer with liquidity protection
    function _safeTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal validSender(_from) {
        emit Print("isValidSender");
        uint256 _commission = _getCommission(_from, _to, _amount);
        emit Print("isValidCommission");
        peachStorage.transfer(_from, _to, _amount, _commission);
        emit Print("Successful transfer");
        emit Transfer(_from, _to, _amount - _commission);
        if (_commission != 0) emit Transfer(_from, rewardsPoolv2, _commission);
    }

    // Transfer
    function transfer(address _to, uint256 _amount)
        public
        isAllowedTransaction(_to, _amount, _balanceOf(msg.sender))
    {
        _safeTransfer(msg.sender, _to, _amount);
        authorizedTransactors[msg.sender] = false;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public isAllowedTransaction(_to, _amount, _balanceOf(_from)) {
        _safeTransferFrom(_from, msg.sender, _to, _amount);
        authorizedTransactors[msg.sender] = false;
    }

    // Approve big liquidity extraction
    function approveTransactor() external {
        authorizedTransactors[msg.sender] = true;
    }

    function renounceOwnership() external onlyOwner {
        owner = address(0);
    }
}
