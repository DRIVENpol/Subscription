// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Subscription based smart contract
 * @notice Pay a monthly subscription erc20 tokens
 * @author Socarde Paul-Constantin, DRIVENlabs Inc.
 */

abstract contract SubscriptionInErc20 is Ownable {
    using SafeERC20 for IERC20;

    /// @dev The subscription fee
    uint256 public erc20Fee;

    /// @dev Variables for analytics
    uint256 public totalPaymentsErc20;

    /// @dev Where the fees will be sent
    address public feeCollector;

    /// @dev IERC20 Object - IERC20
    IERC20 public erc20Token;

    /// @dev Struct for payments
    /// @param user Who made the payment
    /// @param paymentMoment When the last payment was made
    /// @param paymentExpire When the user needs to pay again
    struct Erc20Payment {
        address user; // Who made the payment
        uint256 paymentMoment; // When the last payment was made
        uint256 paymentExpire; // When the user needs to pay again
    }

    /// @dev Array of erc20 payments
    Erc20Payment[] public erc20Payments;

    /// @dev Link an EOA to an ERC20 payment
    mapping(address => Erc20Payment ) public userPaymentErc20;
    mapping(address => uint256) public userTotalPaymentsErc20;

    /// @dev Events
    event UserPaidErc20(address indexed who, uint256 indexed fee, uint256 indexed period);

    /// @dev Errors
    error NotEOA();
    error SubscriptionNotPaid();
    error FailedErc20Transfer();

    /// @dev We transfer the ownership to a given owner
    constructor() Ownable(msg.sender) {
        feeCollector = msg.sender;
    }

    /// @dev Modifier to check if user's subscription is still active
    modifier userPaid() {
        if(block.timestamp >= userPaymentErc20[msg.sender].paymentExpire) revert SubscriptionNotPaid();
        _;
    }

    /// @dev Function to pay the subscription
    /// @param _period For how many months the user wants to pay the subscription
    function paySubscription(uint256 _period) external payable virtual returns(bool) { 
        // We add support for tokens with fees on transfer
        uint256 _balanceBefore = erc20Token.balanceOf(address(this));

        IERC20(erc20Token).safeTransferFrom(msg.sender, address(this), _period * erc20Fee);

        uint256 _balanceAfter = erc20Token.balanceOf(address(this));

        uint256 _delta = _balanceAfter - _balanceBefore;

        unchecked {
            totalPaymentsErc20 += _delta; // Compute total payments in ERC20
            userTotalPaymentsErc20[msg.sender] += _delta; // Compute user's total payments in ERC20         
        }

        Erc20Payment memory newPayment = Erc20Payment(msg.sender, block.timestamp, block.timestamp + _period * 30 days);
        erc20Payments.push(newPayment); // Push the payment in the payments array
        userPaymentErc20[msg.sender] = newPayment; // User's last payment

        emit UserPaidErc20(msg.sender, erc20Fee * _period, _period);

        return true;
    }

    /// @dev Set the monthly Erc20 fee
    function setErc20Fee(uint256 _newErc20Fee) external virtual onlyOwner {
        erc20Fee = _newErc20Fee;
    }

    /// @dev Set the erc20 token for payments
    function setErc20TokenForPayments(address _newErc20Token) external virtual onlyOwner {
        erc20Token = IERC20(_newErc20Token);
    }

    /// @dev Set a new payment collector
    function setNewPaymentCollector(address _feeCollector) public virtual onlyOwner {
        feeCollector = _feeCollector;
    }

    /// @dev Withdraw erc20 tokens
    function withdrawErc20() external virtual onlyOwner {
        uint256 _balance = erc20Token.balanceOf(address(this));
        IERC20(erc20Token).transfer(msg.sender, _balance);
    }

    /// @dev Get the last payment of user in Erc20
    function lastPaymentOfUser(address _user) external view virtual returns(uint256) {
        return userPaymentErc20[_user].paymentMoment;
    }

    /// @dev Get the smart contract's balance of tokens
    function paymentsInSmartContract() external view virtual returns(uint256) {
        return erc20Token.balanceOf(address(this));
    } 
}
