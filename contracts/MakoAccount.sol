// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./core/BaseAccount.sol";
import "./core/TokenCallbackHandler.sol";

contract MakoAccount is
    BaseAccount,
    TokenCallbackHandler,
    UUPSUpgradeable,
    Initializable
{
    using ECDSA for bytes32;

    address public owner;

    IEntryPoint private immutable _entryPoint;

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

    receive() external payable {}

    constructor(IEntryPoint anEntryPoint) {
        _entryPoint = anEntryPoint;
        _disableInitializers();
    }

    function _onlyOwner() internal view {
        require(
            msg.sender == owner || msg.sender == address(this),
            "only owner"
        );
    }

    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external {
        _requireFromEntryPointOrOwner();
        _call(dest, value, func);
    }

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

    function _initialize(address anOwner) internal virtual {
        owner = anOwner;
        emit SimpleAccountInitialized(_entryPoint, owner);
    }

    function _requireFromEntryPointOrOwner() internal view {
        require(
            msg.sender == address(entryPoint()) || msg.sender == owner,
            "account: not Owner or EntryPoint"
        );
    }

    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        if (owner != hash.recover(userOp.signature))
            return SIG_VALIDATION_FAILED;
        return 0;
    }

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

    function _authorizeUpgrade(
        address newImplementation
    ) internal view override {
        (newImplementation);
        _onlyOwner();
    }

    struct Subscription {
        address recipient;
        address token;
        uint256 cost;
        uint256 period;
        uint256 lastProcessed;
        bool active;
    }

    Subscription public activeSubscription;
    uint256 constant PERIOD = 1 hours;

    function subscribeAndActivate(
        address recipient,
        address token
    ) external onlyOwner {
        require(
            activeSubscription.recipient == address(0),
            "Subscription already exists"
        );

        require(
            PERIOD >= 1 hours, // or whatever minimum you want to set
            "Period too short"
        );

        uint256 cost = 3 * 10 ** 18; // Adjusted cost to 3 tokens, assuming they have 18 decimals like ETH

        IERC20 erc20Token = IERC20(token);

        require(
            erc20Token.balanceOf(address(this)) >= cost,
            "Insufficient balance for subscription"
        );

        erc20Token.approve(address(this), cost);

        erc20Token.transferFrom(
            address(this),
            recipient,
            cost
        );

        // Removed the token transfer line from here

        activeSubscription = Subscription({
            recipient: recipient,
            token: token,
            cost: cost,
            period: PERIOD,
            lastProcessed: block.timestamp,
            active: true
        });

        emit SubscriptionCreated(recipient, token, cost, PERIOD);
    }

    function unsubscribe() external onlyOwner {
        require(
            activeSubscription.recipient != address(0),
            "Subscription does not exist"
        );

        delete activeSubscription;

        emit SubscriptionDeleted();
    }

    function processSubscription() external onlyOwner {
        require(
            activeSubscription.recipient != address(0),
            "Subscription does not exist"
        );

        Subscription storage subscription = activeSubscription;

        require(subscription.active, "Subscription is not active");

        if (
            block.timestamp >= subscription.lastProcessed + subscription.period
        ) {
            IERC20 erc20Token = IERC20(subscription.token);

            if (erc20Token.balanceOf(address(this)) < subscription.cost) {
                // If balance is insufficient, cancel the subscription
                delete activeSubscription;
                emit SubscriptionDeleted();
                revert("Insufficient balance for subscription");
            } else {
                erc20Token.transferFrom(
                    address(this),
                    subscription.recipient,
                    subscription.cost
                );
                subscription.lastProcessed = block.timestamp;
                emit SubscriptionProcessed();
            }
        }
    }

    function getSubscription()
        external
        view
        returns (Subscription memory subscription)
    {
        require(
            activeSubscription.recipient != address(0),
            "Subscription does not exist"
        );
        return activeSubscription;
    }
}
