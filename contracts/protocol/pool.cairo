%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address

from contracts.interfaces.i_a_token import IAToken
from contracts.libraries.math.wad_ray_math import ray
from contracts.libraries.types.data_types import DataTypes

from openzeppelin.token.erc20.interfaces.IERC20 import IERC20

#
# Storage
#

@storage_var
func reserve_data(asset : felt) -> (data : DataTypes.ReserveData):
end

@storage_var
func reserves_count() -> (count : felt):
end

@storage_var
func reserve_address_by_id(reserve_id : felt) -> (address : felt):
end


#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    return ()
end

#
# Getters
#

@view
func get_reserve_data{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset : felt
) -> (data : DataTypes.ReserveData):
    let (data) = reserve_data.read(asset=asset)
    return (data=data)
end

@view
func get_reserves_count{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (count : felt):
    let (count) = reserves_count.read()
    return (count=count)
end

@view
func get_reserve_address_by_id{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    reserve_id : felt
) -> (address : felt):
    let (address) = reserve_address_by_id.read(reserve_id=reserve_id)
    return (address=address)
end

# @view
# func get_reserve_normalized_income{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}
#         (asset : felt) -> (res : Uint256):
# end

#
# Externals
#

@external
func supply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset : felt, amount : Uint256, on_behalf_of : felt
):
    alloc_locals

    # TODO: 
    # - check amount not zero
    let (contract_address) = get_contract_address()
    let (caller) = get_caller_address()
    let (data) = get_reserve_data(asset)
    let (underlying) = IAToken.UNDERLYING_ASSET_ADDRESS(contract_address=data.a_token_address)
    let (balance) = IERC20.balanceOf(contract_address=underlying, account=caller)

    # - check transfer success
    IERC20.transferFrom(contract_address=underlying, sender=caller, recipient=contract_address, amount=amount)
    
    # TODO: use proper index instead of 0
    IAToken.mint(contract_address=data.a_token_address, caller=caller, on_behalf_of=on_behalf_of, amount=amount, index=Uint256(1,0))
    return ()
end

@external
func withdraw{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset : felt, amount : Uint256, to : felt
):
    return ()
end

@external
func init_reserve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset : felt, a_token_address : felt
):
    alloc_locals
    let (count) = get_reserves_count()
    let new_count = count + 1

    reserves_count.write(value=new_count)

    let (local RAY) = ray()
    reserve_data.write(
        asset=asset,
        value=DataTypes.ReserveData(
            id=new_count,
            a_token_address=a_token_address,
            liquidity_index=RAY
        )
    )

    reserve_address_by_id.write(
        reserve_id=new_count,
        value=asset
    )

    return ()
end

@external
func drop_reserve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset : felt
):
    return ()
end