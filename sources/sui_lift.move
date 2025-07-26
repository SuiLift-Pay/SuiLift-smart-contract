module sui_lift::transfer;

use sui::coin::{Self, Coin};
use sui::sui::SUI;

public entry fun transfer_sui(
    payment: &mut Coin<SUI>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    let split_coin = coin::split(payment, amount, ctx);
    transfer::public_transfer(split_coin, recipient);
}

public entry fun transfer_all(payment: Coin<SUI>, recipient: address, _ctx: &mut TxContext) {
    transfer::public_transfer(payment, recipient);
}
