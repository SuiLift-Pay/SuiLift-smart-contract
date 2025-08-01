module sui_lift::transfer;

use sui::coin::{Self, Coin};

const FEE_RECIPIENT: address = @0xadd2fb2f8c7f5b3f4fb1e1d4e620818f8b593b1dbec9d35e64bd3757ff8c49ce;

public entry fun transfer_with_fee<T>(
    mut payment: Coin<T>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    assert!(amount > 0, 0);
    let fee = amount * 5 / 1000;
    let net = amount - fee;

    let coin_net = coin::split(&mut payment, net, ctx);
    transfer::public_transfer(coin_net, recipient);

    transfer::public_transfer(payment, FEE_RECIPIENT);
}

public entry fun transfer_no_fee<T>(payment: Coin<T>, recipient: address) {
    transfer::public_transfer(payment, recipient);
}
