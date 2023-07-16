// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;
import "./core/BasePaymaster.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenPaymaster is BasePaymaster {
    IERC20 public token;
    uint256 public constant serviceCost = 1e18; // Cost of service in tokens (1 token)
    event ServicePaid(address indexed user, uint256 amount);

    constructor(
        IEntryPoint _entryPoint,
        IERC20 _token
    ) BasePaymaster(_entryPoint) payable {
        token = _token;
        entryPoint.depositTo{value : msg.value}(address(this));
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

        // Check if the user has enough tokens to pay for the service
        require(token.balanceOf(user) >= serviceCost, "Insufficient tokens");

        // Check if the paymaster is allowed to spend the required amount of tokens on behalf of the user
        require(
            token.allowance(user, address(this)) >= serviceCost,
            "Insufficient allowance"
        );

        // Return the user's address as the context, no validation data is needed
        return (abi.encode(user), 0);
    }

    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 /*actualGasCost*/
    ) internal override {
        // Decode the context
        address user = abi.decode(context, (address));

        // Transfer service cost from the user to the paymaster
        require(
            token.transferFrom(user, address(this), serviceCost),
            "Token transfer failed"
        );

        // Emit the event
        emit ServicePaid(user, serviceCost);

        // Handle different post-operation modes if needed
        if (mode == PostOpMode.opReverted) {
            // The operation was reverted, handle accordingly
            // Implement your logic here
        } else if (mode == PostOpMode.postOpReverted) {
            // The operation was successful, but postOp was reverted in the first call
            // Implement your logic here
        }
    }
}
