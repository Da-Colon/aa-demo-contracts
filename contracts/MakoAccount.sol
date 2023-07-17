// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./core/BaseAccount.sol";
import "./core/TokenCallbackHandler.sol";

/**
 * @title MakoAccount
 * @dev This contract enables users to manage a subscription model. It also provides the basic functionalities
 * to execute transactions, batch transactions and handle deposits.
 */
contract MakoAccount is
    BaseAccount,
    TokenCallbackHandler,
    UUPSUpgradeable,
    Initializable
{
    using ECDSA for bytes32;

    address public owner;

    IEntryPoint private immutable _entryPoint;

    //Event logs
    event SimpleAccountInitialized(
        IEntryPoint indexed entryPoint,
        address indexed owner
    );
    event SubscriptionCreated(
        address indexed recipient,
        address indexed token,
        uint256 tokenId,
        uint256 period
    );
    event SubscriptionDeleted();
    event SubscriptionProcessed();

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    // This function is a fallback function and allows the contract to receive funds
    receive() external payable {}

    constructor(IEntryPoint anEntryPoint) {
        _entryPoint = anEntryPoint;
        _disableInitializers();
    }

    // Internal function to enforce the owner-only restriction
    function _onlyOwner() internal view {
        require(
            msg.sender == owner || msg.sender == address(this),
            "only owner"
        );
    }

    // This function allows the owner or the entry point to execute a transaction on behalf of the contract
    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external {
        _requireFromEntryPointOrOwner();
        _call(dest, value, func);
    }

    // This function allows the owner or the entry point to execute multiple transactions on behalf of the contract
    function executeBatch(
        address[] calldata dest,
        bytes[] calldata func
    ) external {
        _requireFromEntryPointOrOwner();
        require(dest.length == func.length, "wrong array lengths");
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], 0, func[i]);
        }
    }

    function initialize(address anOwner) public virtual initializer {
        _initialize(anOwner);
    }

    // This function is used for initialising the owner of the contract
    function _initialize(address anOwner) internal virtual {
        owner = anOwner;
        emit SimpleAccountInitialized(_entryPoint, owner);
    }

    // This function ensures that the function caller is either the owner of the contract or the entry point
    function _requireFromEntryPointOrOwner() internal view {
        require(
            msg.sender == address(entryPoint()) || msg.sender == owner,
            "account: not Owner or EntryPoint"
        );
    }

    // This function is used for validating the signature of the user operation
    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (owner != hash.recover(userOp.signature))
            return SIG_VALIDATION_FAILED;
        return 0;
    }

    // This function is used for executing a call operation
    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    function addDeposit() public payable {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) public onlyOwner {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    // Function to authorize the upgrade of the contract
    function _authorizeUpgrade(
        address newImplementation
    ) internal view override {
        (newImplementation);
        _onlyOwner();
    }

    /**
     * @dev Struct to hold subscription data
     */
    struct Subscription {
        address recipient; // The address of the subscription recipient
        address token; // The address of the token that will be used for payments
        uint256 cost; // The cost of each subscription period
        uint256 period; // The length of each subscription period (in seconds)
        uint256 lastProcessed; // The timestamp of the last time the subscription was processed
        bool active; // The status of the subscription (true = active, false = not active)
    }

    Subscription public activeSubscription; // The active subscription

    // Constant that represents a period of one hour
    uint256 constant PERIOD = 1 hours;

    /**
     * @dev This function is used to subscribe and activate a subscription.
     * It sets up a new subscription and makes the first payment.
     *
     * Requirements:
     * - There must not be an active subscription.
     * - The cost of the subscription must be less than or equal to the contract's balance of the subscription token.
     *
     * @param recipient The address that will receive the subscription payments.
     * @param token The address of the token that will be used for payments.
     */
    function subscribeAndActivate(
        address recipient,
        address token
    ) external onlyOwner {
        // The subscription must not already exist
        require(
            activeSubscription.recipient == address(0),
            "Subscription already exists"
        );

        // The period must be at least one hour
        require(PERIOD >= 1 hours, "Period too short");

        // The cost of each subscription period is set to 3 tokens
        uint256 cost = 3 * 10 ** 18;

        IERC20 erc20Token = IERC20(token);

        // The contract must have enough tokens to pay the first subscription period
        require(
            erc20Token.balanceOf(address(this)) >= cost,
            "Insufficient balance for subscription"
        );

        // The contract approves itself to spend the subscription cost
        erc20Token.approve(address(this), cost);

        // The contract transfers the subscription cost to the recipient
        erc20Token.transferFrom(address(this), recipient, cost);

        // The active subscription is created
        activeSubscription = Subscription({
            recipient: recipient,
            token: token,
            cost: cost,
            period: PERIOD,
            lastProcessed: block.timestamp,
            active: true
        });

        // An event is emitted to log the creation of the subscription
        emit SubscriptionCreated(recipient, token, cost, PERIOD);
    }

    /**
     * @dev This function is used to unsubscribe from a subscription.
     * It deletes the active subscription.
     *
     * Requirements:
     * - There must be an active subscription.
     */
    function unsubscribe() external onlyOwner {
        // The subscription must exist
        require(activeSubscription.active, "Subscription does not exist");

        // The active subscription is deleted
        delete activeSubscription;

        // An event is emitted to log the deletion of the subscription
        emit SubscriptionDeleted();
    }

    /**
     * @dev This function is used to process the subscription.
     * If the subscription period has passed and there are enough tokens, it makes the next payment.
     *
     * Requirements:
     * - There must be an active subscription.
     * - The subscription must be active.
     * - The contract must have enough tokens to pay the next subscription period.
     */
    function processSubscription() external {
        Subscription storage subscription = activeSubscription;

        // The subscription must be active
        require(subscription.active, "Subscription is not active");

        // If the subscription period has passed
        if (
            block.timestamp >= subscription.lastProcessed + subscription.period
        ) {
            IERC20 erc20Token = IERC20(subscription.token);

            // Check for sufficient token balance for the next subscription period
            uint256 balance = erc20Token.balanceOf(address(this));
            require(
                balance >= subscription.cost,
                "Insufficient balance for subscription"
            );

            // If there are enough tokens, the next subscription payment is made
            erc20Token.transferFrom(
                address(this),
                subscription.recipient,
                subscription.cost
            );
            // The timestamp of the last processed subscription is updated
            subscription.lastProcessed = block.timestamp;
            // An event is emitted to log the processing of the subscription
            emit SubscriptionProcessed();
        }
    }

    /**
     * @dev This function is used to get the active subscription details.
     *
     * Requirements:
     * - There must be an active subscription.
     *
     * Returns the active subscription.
     */
    function getSubscription()
        external
        view
        returns (Subscription memory subscription)
    {
        // The subscription must exist
        require(activeSubscription.active, "Subscription does not exist");
        // The function returns the active subscription
        return activeSubscription;
    }
}
