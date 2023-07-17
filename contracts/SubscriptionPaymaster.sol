// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "./core/BasePaymaster.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MakoAccount.sol";

contract SubscriptionPaymaster is BasePaymaster {
    IERC20 public token;
    uint256 public tokenChargePerHour;

    event ServicePaid(address indexed user, uint256 amount);

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
        address user = userOp.sender;
        MakoAccount account = MakoAccount(payable(userOp.sender));

        // Check if the user has an active subscription
        MakoAccount.Subscription memory subscription = account
            .getSubscription();
        require(subscription.active, "No active subscription");

        // Return the user's address as the context, no validation data is needed
        return (abi.encode(user), 0);
    }

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
