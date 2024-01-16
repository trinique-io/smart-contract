// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
 
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
 
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";


abstract contract Burnable is Context,Ownable {
    address private _burner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error BurnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error BurnableInvalidBurner(address burner);

    event BurnershipTransferred(address indexed previousBurner, address indexed newBurner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialBurner) {
        if (initialBurner == address(0)) {
            revert BurnableInvalidBurner(address(0));
        }
        _transferBurnship(initialBurner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyBurner() {
        _checkBurner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function burner() public view virtual returns (address) {
        return _burner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkBurner() internal view virtual {
        if (burner() != _msgSender()) {
            revert BurnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing burnship will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceBurnship() public virtual onlyOwner {
        _transferBurnship(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferBurnship(address newBurner) public virtual onlyOwner {
        if (newBurner == address(0)) {
            revert BurnableInvalidBurner(address(0));
        }
        _transferBurnship(newBurner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferBurnship(address newBurner) internal virtual {
        address oldBurner = _burner;
        _burner = newBurner;
        emit BurnershipTransferred(oldBurner, newBurner);
    }
}


contract TriniqueToken is ERC20, ERC20Burnable,Ownable,ERC20Pausable,Burnable{

    constructor() ERC20("Trinique", "TNQ") Ownable(msg.sender) Burnable(msg.sender) {
    }

    function decimals() public view virtual  override  returns (uint8) {
        return 6;
    }

    function _update(address from, address to, uint256 value) internal virtual override(ERC20,ERC20Pausable) whenNotPaused {
        super._update(from, to, value);
    }

    function transfer(address to, uint256 value) public whenNotPaused override  returns (bool) {
        require(!isBlackListed[msg.sender]);
        return super.transfer(to, value);
    }
    function transferFrom(address from, address to, uint256 value) public whenNotPaused override returns (bool) {
        require(!isBlackListed[from], "Sender is blacklisted");
        return super.transferFrom(from, to, value);
    }
    // Issue a new amount of tokens
    // these tokens are deposited into the owner address
    //
    // @param _amount Number of tokens to be issued
    function issue(uint256 amount) public onlyOwner {
        _mint(msg.sender, amount *10 ** decimals());
    }

    function issueTo(address to, uint256 amount) public onlyOwner {
        _mint(to, amount * 10**decimals());
    }

    /****************************************************/
    /**************           Burn           ************/
    /****************************************************/
    function burnRedeem(uint256 amount) public onlyBurner {
        burn(amount * 10**decimals());
    }

    /****************************************************/
    /**************       Multi Send         ************/
    /****************************************************/
    function multiSend(address[] calldata froms, address[] calldata tos, uint256[] calldata values) external whenNotPaused {
        require(froms.length == tos.length && tos.length == values.length, "Invalid input arrays");

        uint256 totalValue;

        for (uint i = 0; i < froms.length; i++) {
            require(!isBlackListed[froms[i]], "Sender is blacklisted");

            // Add a check for total value
            totalValue += values[i];

            require(totalValue <= type(uint256).max, "Total value overflow");

            _update(froms[i], tos[i], values[i]);

            // Emit TransferSuccess event
            emit TransferSuccess(froms[i], tos[i], values[i]);
        }
    }

    // Event to announce successful transfers
    event TransferSuccess(address indexed from, address indexed to, uint256 value);

    // Event to announce errors
    event TransferError(address indexed from, address indexed to, uint256 value, string errorMessage);


    /****************************************************/
    /**************       BLACK LIST         ************/
    /****************************************************/
    
    /////// Getters to allow the same blacklist to be used also by other contracts (including upgraded Tether) ///////
    function getBlackListStatus(address _maker) external view returns (bool) {
        return isBlackListed[_maker];
    }

    mapping (address => bool) public isBlackListed;
    
    function addBlackList (address _evilUser) public onlyOwner {
        isBlackListed[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }

    function removeBlackList (address _clearedUser) public onlyOwner {
        isBlackListed[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }

    event AddedBlackList(address _user);

    event RemovedBlackList(address _user);

}
