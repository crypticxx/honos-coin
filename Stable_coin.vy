event Transfer:
    _from: indexed(address)
    _to: indexed(address)
    _value: uint256

event Approval:
    _owner: indexed(address)
    _spender: indexed(address)
    _value: uint256

event Freeze:
    _account: indexed(address)
    _freeze: bool

name: public(String[10])
symbol: public(String[3])
totalSupply: public(uint256)
decimals: public(uint256)
balances: HashMap[address, uint256]
allowed: HashMap[address, HashMap[address, uint256]]
frozenBalances: public(HashMap[address, bool])
owner: public(address)

interface EcoMgr:
    def fulfill(_purchaser: address, _amount: uint256) -> uint256: payable

@external
def __init__():
    _initialSupply: uint256 = 6000000000
    _decimals: uint256 = 2
    self.totalSupply = _initialSupply * 10 ** _decimals
    self.balances[msg.sender] = self.totalSupply
    self.name = 'Honos Coin'
    self.symbol = 'HON'
    self.decimals = _decimals
    self.owner = msg.sender
    log Transfer(ZERO_ADDRESS, msg.sender, self.totalSupply)


@external
def freezeBalance(_target: address, _freeze: bool) -> bool:
    assert msg.sender == self.owner
    self.frozenBalances[_target] = _freeze
    log Freeze(_target, _freeze)
    return True

@external
def mintToken(_mintedAmount: uint256) -> bool:
    assert msg.sender == self.owner
    self.totalSupply += _mintedAmount
    self.balances[msg.sender] += _mintedAmount
    log Transfer(ZERO_ADDRESS, msg.sender, _mintedAmount)

    return True

@external
def burn(_burntAmount: uint256) -> bool:
    assert msg.sender == self.owner
    assert self.balances[msg.sender] >= _burntAmount
    self.totalSupply -= _burntAmount
    self.balances[msg.sender] -= _burntAmount
    log Transfer(msg.sender, ZERO_ADDRESS, _burntAmount)

    return True

@external
def balanceOf(_owner: address) -> uint256:
    return self.balances[_owner]

@external
def transfer(_to: address, _amount: uint256) -> bool:
    assert self.balances[msg.sender] >= _amount
    assert self.frozenBalances[msg.sender] == False
    self.balances[msg.sender] -= _amount
    self.balances[_to] += _amount
    log Transfer(msg.sender, _to, _amount)

    return True

@external
def transferFrom(_from: address, _to: address, _value: uint256) -> bool:
    assert _value <= self.allowed[_from][msg.sender]
    assert _value <= self.balances[_from]
    assert self.frozenBalances[msg.sender] == False

    self.balances[_from] -= _value
    self.allowed[_from][msg.sender] -= _value
    self.balances[_to] += _value
    log Transfer(_from, _to, _value)

    return True

@external
def approve(_spender: address, _amount: uint256) -> bool:
    self.allowed[msg.sender][_spender] = _amount
    log Approval(msg.sender, _spender, _amount)

    return True

@external
def allowance(_owner: address, _spender: address) -> uint256:
    return self.allowed[_owner][_spender]
