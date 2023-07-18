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

    // Add this at the top of your contract
    event ValidatingPaymasterUserOp(address user, uint256 currentBlock);
    event ValidationPaymaster(address sender, bytes paymasterData);

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
        emit ValidationPaymaster(userOp.sender, userOp.paymasterAndData);
        require(
            userOp.paymasterAndData.length >= 72,
            "Invalid paymaster data length"
        );

        address paymasterAddress = address(
            bytes20(userOp.paymasterAndData[0:20])
        );

        require(paymasterAddress == address(this), "Invalid paymaster address");

        uint256 currentBlock = uint256(bytes32(userOp.paymasterAndData[20:52]));

        address smartAddress = address(bytes20(userOp.paymasterAndData[52:72]));

        MakoAccount account = MakoAccount(payable(smartAddress));

        // Emit an event for the validation
        emit ValidatingPaymasterUserOp(userOp.sender, currentBlock);

        // Try to process the subscription; send the current block number as parameter
        try account.processSubscription(currentBlock) {} catch Error(
            string memory reason
        ) {
            // If the processing fails (e.g., due to insufficient balance), revert the transaction with the reason
            revert(
                string(
                    abi.encodePacked("Process subscription failed: ", reason)
                )
            );
        } catch {
            revert("Process subscription failed: unknown error");
        }

        // Return the user's address as the context, no validation data is needed
        return (abi.encode(userOp.sender), 0);
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
