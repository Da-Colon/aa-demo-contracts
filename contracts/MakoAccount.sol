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
        address recipient;
        address token;
        uint256 cost;
        uint256 period; // Period is now in blocks
        uint256 lastProcessedBlock; // Replaced timestamp with block number
        bool active;
    }

    Subscription public activeSubscription;

    // Constants for block periods
    uint256 public constant BLOCKS_PER_HOUR = 120; // Approximately 4 blocks per minute * 60 minutes
    uint256 public constant PERIOD = 1 * BLOCKS_PER_HOUR;

    function subscribeAndActivate(
        address recipient,
        address token
    ) external onlyOwner {
        require(!activeSubscription.active, "Subscription already exists");
        require(PERIOD >= BLOCKS_PER_HOUR, "Period too short"); // 1 hour minimum

        uint256 cost = 3 * 10 ** 18;
        IERC20 erc20Token = IERC20(token);
        require(
            erc20Token.balanceOf(address(this)) >= cost,
            "Insufficient balance for subscription"
        );

        // Create the active subscription
        activeSubscription = Subscription({
            recipient: recipient,
            token: token,
            cost: cost,
            period: PERIOD,
            lastProcessedBlock: block.number, // Use block.number
            active: true
        });
        erc20Token.approve(address(this), cost);
        erc20Token.transferFrom(address(this), recipient, cost);


        emit SubscriptionCreated(recipient, token, cost, PERIOD);
    }

    function processSubscription(uint256 currentBlock) external {
        Subscription storage subscription = activeSubscription;

        require(subscription.active, "Subscription is not active");

        // If the subscription period has passed
        if (
            currentBlock >=
            subscription.lastProcessedBlock + subscription.period
        ) {
            IERC20 erc20Token = IERC20(subscription.token);

            // Check for sufficient token balance for the next subscription period
            uint256 balance = erc20Token.balanceOf(address(this));
            require(
                balance >= subscription.cost,
                "Insufficient balance for subscription"
            );

            // If there are enough tokens, the next subscription payment is made
            erc20Token.transfer(subscription.recipient, subscription.cost);

            // The block number of the last processed subscription is updated
            subscription.lastProcessedBlock = currentBlock;

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
