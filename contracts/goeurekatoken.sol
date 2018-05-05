pragma solidity ^0.4.23;

import "./openzeppelin-solidity/contracts/token/ERC20/MintableToken.sol";
import "./openzeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./xClaimable.sol";
import "./Salvageable.sol";



contract GOeureka is xClaimable, MintableToken, Pausable, Salvageable {
    // Coin Properties
    string public name = "GOeureka";
    string public symbol = "GET";
    uint256 public decimals = 18;

    // Special propeties
    bool public tradingStarted = false;

    /**
    * @dev modifier that throws if trading has not started yet
    */
    modifier hasStartedTrading() {
        require(tradingStarted);
        require(!paused);
        _;
    }

    /**
    * @dev Allows the owner to enable the trading. This can not be undone
    */
    function startTrading() public onlyOwner {
        tradingStarted = true;
    }

    /**
    * @dev Allows anyone to transfer the Go tokens once trading has started
    * @param _to the recipient address of the tokens.
    * @param _value number of tokens to be transfered.
   */
    function transfer(address _to, uint _value) hasStartedTrading public returns (bool) {
        return super.transfer(_to, _value);
    }

    /**
    * @dev Allows anyone to transfer the Go tokens once trading has started
    * @param _from address The address which you want to send tokens from
    * @param _to address The address which you want to transfer to
    * @param _value uint the amout of tokens to be transfered
    */
    function transferFrom(address _from, address _to, uint _value) hasStartedTrading public returns (bool) {
        return super.transferFrom(_from, _to, _value);
    }

    /**
     * Set allowance for other address and notify
     *
     * Allows `_spender` to spend no more than `_value` tokens on your behalf, and then ping the contract about it
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     * @param _extraData some extra information to send to the approved contract
     */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData)
        public
        returns (bool success) 
    {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }


}