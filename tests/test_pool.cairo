%lang starknet

from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_sub, uint256_eq
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address

from openzeppelin.token.erc20.interfaces.IERC20 import IERC20
from contracts.libraries.math.wad_ray_math import RAY
from contracts.libraries.types.data_types import DataTypes

from contracts.interfaces.i_a_token import IAToken
from contracts.interfaces.i_pool import IPool

const PRANK_USER_1 = 111
const PRANK_USER_2 = 222
const NAME = 123
const SYMBOL = 456
const DECIMALS = 18
const INITIAL_SUPPLY_LOW = 1000
const INITIAL_SUPPLY_HIGH = 0
const AMOUNT = 10

@view
func __setup__{syscall_ptr : felt*, range_check_ptr}():
    %{
        context.pool = deploy_contract("./contracts/protocol/pool.cairo", []).contract_address
        context.token = deploy_contract("./lib/cairo_contracts/src/openzeppelin/token/erc20/ERC20.cairo", [ids.NAME, ids.SYMBOL, ids.DECIMALS, ids.INITIAL_SUPPLY_LOW, ids.INITIAL_SUPPLY_HIGH, ids.PRANK_USER_1]).contract_address
        context.a_token = deploy_contract("./contracts/protocol/a_token.cairo", [context.pool, context.token, ids.DECIMALS, ids.NAME+1, ids.SYMBOL+1]).contract_address
    %}
    return ()
end

func get_contract_addresses() -> (
    pool_address : felt, token_address : felt, a_token_address : felt
):
    tempvar pool
    tempvar token
    tempvar a_token
    %{ ids.pool = context.pool %}
    %{ ids.token = context.token %}
    %{ ids.a_token = context.a_token %}
    return (pool, token, a_token)
end

# @view
# func test_init_reserve{syscall_ptr : felt*, range_check_ptr, pedersen_ptr : HashBuiltin*}():
#     alloc_locals
#     let (local pool, local token, local a_token) = get_contract_addresses()

#     let (count_before) = IPool.get_reserves_count(pool)
#     let (reserve_data_before) = IPool.get_reserve_data(pool, SYMBOL)
#     assert reserve_data_before = DataTypes.ReserveData(0, 0, Uint256(0,0))

#     IPool.init_reserve(pool, SYMBOL, a_token)

#     let (count_after) = IPool.get_reserves_count(pool)
#     let (reserve_data_after) = IPool.get_reserve_data(pool, SYMBOL)
#     assert count_after - count_before = 1
#     assert reserve_data_after = DataTypes.ReserveData(count_after, a_token, Uint256(RAY,0))

#     return ()
# end

@view
func test_supply{syscall_ptr : felt*, range_check_ptr, pedersen_ptr : HashBuiltin*}():
    alloc_locals
    let (local pool, local token, local a_token) = get_contract_addresses()
    
    %{ stop_mock = mock_call(ids.pool, "get_reserve_normalized_income", [ids.RAY, 0]) %}
    let (contract_token_balance_before) = IERC20.balanceOf(token, pool)
    let (user_token_balance_before) = IERC20.balanceOf(token, PRANK_USER_1)
    let (recipient_a_token_balance_before) = IAToken.balanceOf(a_token, PRANK_USER_1)
    %{ stop_mock() %}
    

    %{ stop_prank_callable = start_prank(ids.PRANK_USER_1) %}
    %{ stop_mock = mock_call(ids.a_token, "UNDERLYING_ASSET_ADDRESS", [ids.token]) %}
    IPool.supply(pool, SYMBOL, Uint256(AMOUNT, 0), PRANK_USER_1)
    %{ stop_prank_callable() %}
    %{ stop_mock() %}

    %{ stop_mock = mock_call(ids.pool, "get_reserve_normalized_income", [ids.RAY, 0]) %}
    let (contract_token_balance_after) = IERC20.balanceOf(token, pool)
    let (user_token_balance_after) = IERC20.balanceOf(token, PRANK_USER_1)
    let (recipient_a_token_balance_after) = IAToken.balanceOf(a_token, PRANK_USER_1)
    %{ stop_mock() %}

    let (contract_token_balance_difference) = uint256_sub(contract_token_balance_after, contract_token_balance_before)
    let (user_token_balance_difference) = uint256_sub(user_token_balance_before, user_token_balance_after)
    let (recipient_a_token_balance_difference) = uint256_sub(recipient_a_token_balance_after, recipient_a_token_balance_before)

    let (contract_token_balance_correct) = uint256_eq(contract_token_balance_difference, Uint256(AMOUNT, 0))
    let (user_token_balance_corrrect) = uint256_eq(user_token_balance_difference, Uint256(AMOUNT, 0))
    let (recipient_a_token_balance_correct) = uint256_eq(recipient_a_token_balance_difference, Uint256(AMOUNT, 0))
    
    assert contract_token_balance_correct = 1
    assert user_token_balance_corrrect = 1
    assert recipient_a_token_balance_correct = 1

    return ()
end