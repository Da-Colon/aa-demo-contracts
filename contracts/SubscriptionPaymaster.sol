// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "./core/BasePaymaster.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MakoAccount.sol";

/**
 * @title SubscriptionPaymaster
 * @dev This contract extends BasePaymaster to add subscription logic to the paymaster. It will cover the gas cost
 *      of transactions that originate from accounts with an active subscription.
 */
contract SubscriptionPaymaster is BasePaymaster {
    IERC20 public token;
    uint256 public tokenChargePerHour;

    event ServicePaid(address indexed user, uint256 amount);

    /**
     * @dev Sets up the SubscriptionPaymaster with the EntryPoint to use, the ERC20 token that will be used for
     *      subscriptions, and the cost per hour in tokens for the subscription.
     * @param _entryPoint The EntryPoint contract to use.
     * @param _token The ERC20 token to use for subscriptions.
     * @param _tokenChargePerHour The cost in tokens per hour for the subscription.
     */
    constructor(
        IEntryPoint _entryPoint,
        IERC20 _token,
        uint256 _tokenChargePerHour
    ) payable BasePaymaster(_entryPoint) {
        token = _token;
        tokenChargePerHour = _tokenChargePerHour;
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    /**
     * @dev Implements the abstract method from BasePaymaster. This method validates the user's operation by checking
     *      if the user has an active subscription.
     * @param userOp The user operation to validate.
     */
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 /*maxCost*/
    ) internal virtual override returns (bytes memory context, uint256 validationData) {
        address user = userOp.sender;
        MakoAccount account = MakoAccount(payable(userOp.sender));

        // Check if the user has an active subscription
        MakoAccount.Subscription memory subscription = account
            .getSubscription();
        require(subscription.active, "No active subscription");

        // Return the user's address as the context, no validation data is needed
        return (abi.encode(user), 0);
    }

    /**
     * @dev Implements the abstract method from BasePaymaster. This method handles different post-operation modes.
     * @param mode The mode of the post-operation. It can be either a reverted operation, a successful operation,
     *      or a reverted post-operation.
     */
    function _postOp(
        PostOpMode mode,
        bytes calldata /*context*/,
        uint256 /*actualGasCost*/
    ) internal virtual override {
        // Handle different post-operation modes if needed
        if (mode == PostOpMode.opReverted) {
            // The operation was reverted, handle accordingly
        } else if (mode == PostOpMode.postOpReverted) {
            // The operation was successful, but postOp was reverted in the first call
        }
    }
}
