%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.uint256 import Uint256, uint256_lt, uint256_le
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address

from contracts.interfaces.i_a_token import IAToken
from contracts.libraries.math.wad_ray_math import ray_mul, ray
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
func reserve_list(reserve_id : felt) -> (asset : felt):
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
    let (asset) = reserve_list.read(reserve_id=reserve_id)
    let (data) = reserve_data.read(asset=asset)
    return (address=data.a_token_address)
end

@view
func get_reserve_normalized_income{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset : felt
) -> (res : Uint256):
    let (data) = reserve_data.read(asset)
    return (data.liquidity_index)
end

#
# Externals
#

@external
func supply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset : felt, amount : Uint256, on_behalf_of : felt
):
    alloc_locals

    assert_not_zero(asset)
    assert_not_zero(on_behalf_of)
    let (amount_gt_zero) = uint256_lt(Uint256(0, 0), amount)
    assert_not_zero(amount_gt_zero)

    let (caller) = get_caller_address()
    let (data) = get_reserve_data(asset)
    let (underlying) = IAToken.UNDERLYING_ASSET_ADDRESS(contract_address=data.a_token_address)

    let (success) = IERC20.transferFrom(contract_address=underlying, sender=caller, recipient=data.a_token_address, amount=amount)
    assert_not_zero(success)

    let (mint_success) = IAToken.mint(contract_address=data.a_token_address, caller=caller, on_behalf_of=on_behalf_of, amount=amount, index=data.liquidity_index)
    assert_not_zero(mint_success)

    return ()
end

@external
func withdraw{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset : felt, amount : Uint256, to : felt
):
    alloc_locals

    assert_not_zero(asset)
    assert_not_zero(to)
    let (amount_gt_zero) = uint256_lt(Uint256(0, 0), amount)
    assert_not_zero(amount_gt_zero)

    let (caller) = get_caller_address()
    let (data) = get_reserve_data(asset)

    let (scaled_balance) = IAToken.scaled_balance_of(data.a_token_address, caller)

    let (user_balance) = ray_mul(scaled_balance, data.liquidity_index)

    with_attr error_message("Not enough available user balance"):
        let (le) = uint256_le(amount, user_balance)
        assert le = TRUE
    end
    
    let (burn_success) = IAToken.burn(contract_address=data.a_token_address, from_=caller, receiver_or_underlying=to, amount=amount, index=data.liquidity_index)
    assert_not_zero(burn_success)

    return ()
end

@external
func init_reserve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset : felt, a_token_address : felt
):
    alloc_locals

    with_attr error_message("The reserve for asset {asset} already exists."):
        let (reserve) = reserve_data.read(asset)
        assert reserve.a_token_address = 0
    end
    let (count) = get_reserves_count()
    # Leave id 0 blank
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

    reserve_list.write(
        reserve_id=new_count,
        value=asset
    )

    return ()
end

@external
func drop_reserve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    asset : felt
):
    alloc_locals

    assert_not_zero(asset)

    let (data) = get_reserve_data(asset)
    let (current_count) = get_reserves_count()
    let (asset_to_swap) = reserve_list.read(reserve_id=current_count)
    let (data_of_asset_to_swap) = get_reserve_data(asset_to_swap)

    # current_count = 1
    if current_count == 1:
        reserve_list.write(reserve_id=current_count, value=0)

        reserve_data.write(
            asset=asset, 
            value=DataTypes.ReserveData(
                id=0,
                a_token_address=0,
                liquidity_index=Uint256(0,0)
            )
        )
        reserves_count.write(0)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        reserve_list.write(reserve_id=current_count, value=0)
        reserve_list.write(reserve_id=data.id, value=asset_to_swap)

        reserve_data.write(
            asset=asset, 
            value=DataTypes.ReserveData(
                id=0,
                a_token_address=0,
                liquidity_index=Uint256(0,0)
            )
        )

        reserve_data.write(
            asset=asset_to_swap, 
            value=DataTypes.ReserveData(
                id=data.id,
                a_token_address=data_of_asset_to_swap.a_token_address,
                liquidity_index=data_of_asset_to_swap.liquidity_index
            )
        )

        reserves_count.write(current_count - 1)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    return ()
end