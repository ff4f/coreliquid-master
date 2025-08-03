// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenVault is ERC4626 {
    constructor(
        address _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(IERC20(_asset)) ERC20(_name, _symbol) {}
    
    function totalAssets() public view virtual override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }
    
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        IERC20(asset()).transferFrom(caller, address(this), assets);
        _mint(receiver, shares);
        
        emit Deposit(caller, receiver, assets, shares);
    }
    
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal virtual override {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }
        
        _burn(owner, shares);
        IERC20(asset()).transfer(receiver, assets);
        
        emit Withdraw(caller, receiver, owner, assets, shares);
    }
}
