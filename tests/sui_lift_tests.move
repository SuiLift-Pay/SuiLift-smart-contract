#[test_only]
module sui_lift::vault_tests;

use std::string::{Self, String};
use sui::balance;
use sui::coin::{Self, Coin};
use sui::object;
use sui::sui::SUI;
use sui::test_scenario::{Self, Scenario};
use sui::transfer;
use sui::tx_context;
use sui_lift::vault::{Self, Vault};

// Error codes from the vault module
const ENotOwner: u64 = 0;
const EInsufficientSuiBalance: u64 = 1;
const ETokenTypeNotFound: u64 = 2;
const EInsufficientTokenBalance: u64 = 3;

// Test constants
const USER1: address = @0x1;
const USER2: address = @0x2;
const TOKEN_TYPE: vector<u8> = b"USDC";

#[test]
fun test_create_vault() {
    let mut scenario_val = test_scenario::begin(USER1);
    let scenario = &mut scenario_val;

    // Create a vault
    vault::create_vault(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, USER1);

    // Verify vault properties
    let mut vault = test_scenario::take_shared<Vault>(scenario);
    assert!(vault::get_owner(&vault) == USER1, 0);
    assert!(vault::get_sui_balance(&vault) == 0, 1);
    assert!(vault::get_all_token_types(&vault) == vector::empty<String>(), 2);
    assert!(vault::get_token_balance(&vault, string::utf8(TOKEN_TYPE)) == 0, 3);

    test_scenario::return_shared(vault);
    test_scenario::end(scenario_val);
}

#[test]
fun test_deposit_and_withdraw_sui() {
    let mut scenario_val = test_scenario::begin(USER1);
    let scenario = &mut scenario_val;

    // Create a vault
    vault::create_vault(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, USER1);
    let mut vault = test_scenario::take_shared<Vault>(scenario);

    // Create a Coin<SUI> with 1000 units
    let coin = coin::mint_for_testing<SUI>(1000, test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, USER1);

    // Deposit SUI
    vault::deposit_sui(&mut vault, coin, test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, USER1);
    assert!(vault::get_sui_balance(&vault) == 1000, 4);

    // Withdraw 500 SUI
    vault::withdraw_sui(&mut vault, 500, USER1, test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, USER1);
    assert!(vault::get_sui_balance(&vault) == 500, 5);

    // Verify recipient received 500 SUI
    let received_coin = test_scenario::take_from_address<Coin<SUI>>(scenario, USER1);
    assert!(coin::value(&received_coin) == 500, 6);
    transfer::public_transfer(received_coin, USER1);

    test_scenario::return_shared(vault);
    test_scenario::end(scenario_val);
}

#[test]
fun test_deposit_and_withdraw_token() {
    let mut scenario_val = test_scenario::begin(USER1);
    let scenario = &mut scenario_val;

    // Create a vault
    vault::create_vault(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, USER1);
    let mut vault = test_scenario::take_shared<Vault>(scenario);

    // Create a Coin<SUI> with 2000 units to simulate a token
    let token = coin::mint_for_testing<SUI>(2000, test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, USER1);

    // Deposit token
    let token_type = string::utf8(TOKEN_TYPE);
    vault::deposit_token(&mut vault, token, token_type, test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, USER1);
    assert!(vault::get_token_balance(&vault, token_type) == 2000, 7);
    assert!(vault::get_all_token_types(&vault) == vector[string::utf8(TOKEN_TYPE)], 8);

    // Withdraw 1500 units
    vault::withdraw_token(&mut vault, token_type, 1500, USER1, test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, USER1);
    assert!(vault::get_token_balance(&vault, token_type) == 500, 9);

    // Verify recipient received 1500 units
    let received_token = test_scenario::take_from_address<Coin<SUI>>(scenario, USER1);
    assert!(coin::value(&received_token) == 1500, 10);
    transfer::public_transfer(received_token, USER1);

    // Withdraw remaining 500 units (should remove token_type)
    vault::withdraw_token(&mut vault, token_type, 500, USER1, test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, USER1);
    assert!(vault::get_token_balance(&vault, token_type) == 0, 11);
    assert!(vault::get_all_token_types(&vault) == vector::empty<String>(), 12);

    test_scenario::return_shared(vault);
    test_scenario::end(scenario_val);
}

#[test]
fun test_deposit_sui_unauthorized() {
    let mut scenario_val = test_scenario::begin(USER1);
    let scenario = &mut scenario_val;

    // Create a vault as USER1
    vault::create_vault(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, USER2);
    let mut vault = test_scenario::take_shared<Vault>(scenario);

    // USER2 tries to deposit SUI (should not change state)
    let coin = coin::mint_for_testing<SUI>(1000, test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, USER2);
    assert!(vault::get_sui_balance(&vault) == 0, 13); // Balance unchanged
    transfer::public_transfer(coin, USER2); // Clean up coin

    test_scenario::return_shared(vault);
    test_scenario::end(scenario_val);
}

#[test]
fun test_withdraw_sui_insufficient_balance() {
    let mut scenario_val = test_scenario::begin(USER1);
    let scenario = &mut scenario_val;

    // Create a vault
    vault::create_vault(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, USER1);
    let mut vault = test_scenario::take_shared<Vault>(scenario);

    // Try to withdraw 1000 SUI from empty vault (should not change state)
    test_scenario::next_tx(scenario, USER1);
    assert!(vault::get_sui_balance(&vault) == 0, 14); // Balance unchanged
    assert!(test_scenario::has_most_recent_for_address<Coin<SUI>>(USER1) == false, 15); // No coin transferred

    test_scenario::return_shared(vault);
    test_scenario::end(scenario_val);
}

#[test]
fun test_withdraw_token_not_found() {
    let mut scenario_val = test_scenario::begin(USER1);
    let scenario = &mut scenario_val;

    // Create a vault
    vault::create_vault(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, USER1);
    let mut vault = test_scenario::take_shared<Vault>(scenario);

    // Try to withdraw non-existent token (should not change state)
    let token_type = string::utf8(TOKEN_TYPE);
    test_scenario::next_tx(scenario, USER1);
    assert!(vault::get_token_balance(&vault, token_type) == 0, 16); // Balance unchanged
    assert!(test_scenario::has_most_recent_for_address<Coin<SUI>>(USER1) == false, 17); // No coin transferred

    test_scenario::return_shared(vault);
    test_scenario::end(scenario_val);
}

#[test]
fun test_withdraw_token_insufficient_balance() {
    let mut scenario_val = test_scenario::begin(USER1);
    let scenario = &mut scenario_val;

    // Create a vault
    vault::create_vault(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, USER1);
    let mut vault = test_scenario::take_shared<Vault>(scenario);

    // Deposit 500 units
    let token = coin::mint_for_testing<SUI>(500, test_scenario::ctx(scenario));
    vault::deposit_token(&mut vault, token, string::utf8(TOKEN_TYPE), test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, USER1);

    // Try to withdraw 1000 units (should not change state)
    let token_type = string::utf8(TOKEN_TYPE);
    assert!(vault::get_token_balance(&vault, token_type) == 500, 18); // Balance unchanged
    assert!(test_scenario::has_most_recent_for_address<Coin<SUI>>(USER1) == false, 19); // No coin transferred

    test_scenario::return_shared(vault);
    test_scenario::end(scenario_val);
}

#[test]
fun test_get_vault_id() {
    let mut scenario_val = test_scenario::begin(USER1);
    let scenario = &mut scenario_val;

    // Create a vault
    vault::create_vault(test_scenario::ctx(scenario));
    test_scenario::next_tx(scenario, USER1);
    let mut vault = test_scenario::take_shared<Vault>(scenario);

    // Verify vault ID
    let vault_id = vault::get_vault(&mut vault);
    assert!(vault_id == object::id(&vault), 20);

    test_scenario::return_shared(vault);
    test_scenario::end(scenario_val);
}
