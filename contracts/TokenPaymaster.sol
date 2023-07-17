// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "./core/BasePaymaster.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TokenPaymaster
 * @dev This contract extends the BasePaymaster by introducing a cost associated with each service call,
 *      payable in a specified ERC20 token. The paymaster will cover the gas costs, but will require the user
 *      to have an adequate token balance and allowance set for the paymaster to collect payment.
 */
contract TokenPaymaster is BasePaymaster {
    IERC20 public token;

    // Fixed cost per service call in tokens.
    uint256 public constant serviceCost = 1e18;

    // Emitted when service is paid for by the user.
    event ServicePaid(address indexed user, uint256 amount);

    /**
     * @dev Constructs a TokenPaymaster.
     * @param _entryPoint The EntryPoint associated with this paymaster.
     * @param _token The ERC20 token accepted for service payments.
     */
    constructor(
        IEntryPoint _entryPoint,
        IERC20 _token
    ) payable BasePaymaster(_entryPoint) {
        token = _token;
        // Deposit ETH into the EntryPoint for covering gas costs.
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    /**
     * @dev Validates the user operation by checking the user's token balance and allowance.
     * @param userOp The user operation.
     * @return context The user's address encoded as the context for the postOp call.
     * @return validationData Unused, returns 0.
     */
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 /*maxCost*/
    )
        internal
        virtual
        override
        returns (bytes memory context, uint256 validationData)
    {
        address user = userOp.sender;

        // Check if the user has enough tokens to pay for the service.
        require(token.balanceOf(user) >= serviceCost, "Insufficient tokens");

        // Check if the paymaster is allowed to spend the required amount of tokens on behalf of the user.
        require(
            token.allowance(user, address(this)) >= serviceCost,
            "Insufficient allowance"
        );

        // Return the user's address as the context, no validation data is needed.
        return (abi.encode(user), 0);
    }

    /**
     * @dev Post-operation method, collects payment from the user for the service.
     * @param mode Describes the mode of the operation.
     * @param context The context from the validatePaymasterUserOp call.
     */
    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 /*actualGasCost*/
    ) internal override {
        // Decode the context to get the user's address.
        address user = abi.decode(context, (address));

        // Transfer service cost from the user to the paymaster.
        require(
            token.transferFrom(user, address(this), serviceCost),
            "Token transfer failed"
        );

        // Emit the ServicePaid event.
        emit ServicePaid(user, serviceCost);

        // If needed, handle different post-operation modes.
        if (mode == PostOpMode.opReverted) {
            // The operation was reverted, handle accordingly.
            // Implement your logic here.
        } else if (mode == PostOpMode.postOpReverted) {
            // The operation was successful, but postOp was reverted in the first call.
            // Implement your logic here.
        }
    }
}
