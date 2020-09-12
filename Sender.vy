# Written in Vyper ver 0.2.4
# Last known update: 9/12/20
# @dev Interface for Ether contributions
# Contributors: Evan Bilotta

event SendEther:
	_to: indexed(address)
	_from: indexed(address)
	_amount: uint256

sender: public(address) # Address of wallet containing ether
token: public(address) # Address of Crowdsale contract
amount: uint256

@external
def __init__():
	self.sender = msg.sender

@external
@payable
def send(_amount: uint256, _to: address):
	log SendEther(self.token, msg.sender, _amount)

@external
@payable
def __default__(_amount: uint256):
	log SendEther(self.token, msg.sender, _amount)
