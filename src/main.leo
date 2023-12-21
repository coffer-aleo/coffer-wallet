// Copyright 2023 Ilia Belkin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See
// the License for the specific language governing permissions and limitations
// under the License.

program coffer_v003.aleo {

    // ██████████████████████████████████████████████████████████████████████
    //                                 Wallet
    // ██████████████████████████████████████████████████████████████████████

    struct WalletInfo {
        wallet_id: field,

        holder1: address,
        holder2: address,
        holder3: address,
        holder4: address,
        holder5: address,
        holder6: address,
        holder7: address,
        holder8: address,
        holder9: address,

        holder_count: u8,
        threshold: u8
    }

    record WalletHolder {
        owner: address,
        owner_id: u8,
        wallet: WalletInfo,
    }

    record PendingTransfer {
        owner: address,
        transfer_id: field,
        creator: address,
        wallet: WalletInfo,
        token_id: u64,
        amount: u128,
        to_address: address, // one and only one of theese two fields
        to_wallet_id: field, // must be non-empty
    }

    record SignedTransfer {
        owner: address,
        transfer_id: field,
        creator: address,
        wallet: WalletInfo,
        token_id: u64,
        amount: u128,
        to_address: address,
        to_wallet_id: field, 
        confirmed: bool, // true means confirmed, false means rejected
    }

    struct WalletBalanceKey {
        wallet_id: field,
        token_id: u64
    }

    struct TransferStatus {
        confirmation_count: u8,
        rejection_count: u8,
        status: u8, // 0 - created, 1 - executed, 2 - rejected
    }

    // wallet_id -> exists or not
    mapping wallet_exists: field => bool;

    // hash(wallet_id, token_id) -> token balance
    mapping wallet_balances: field => u128;

    // transfer_id -> TransferStatus
    mapping transfers: field => TransferStatus;

    transition create_wallet3(owner1: address, owner2: address, owner3: address, threshold: u8, wallet_id: field) -> (WalletHolder, WalletHolder, WalletHolder) {
        let holder_count: u8 = 3u8;
        let zero_address: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;
        
        assert (threshold > 0u8 && threshold <= holder_count);
        assert (owner1 != owner2);

        let wallet_info: WalletInfo = WalletInfo {
            wallet_id: wallet_id,

            holder1: owner1,
            holder2: owner2,
            holder3: owner3,
            holder4: zero_address,
            holder5: zero_address,
            holder6: zero_address,
            holder7: zero_address,
            holder8: zero_address,
            holder9: zero_address,

            holder_count: holder_count,
            threshold: threshold
        };

        let wallet_holder1: WalletHolder = WalletHolder {
            owner: owner1,
            owner_id: 1u8,
            wallet: wallet_info
        };
        let wallet_holder2: WalletHolder = WalletHolder {
            owner: owner2,
            owner_id: 2u8,
            wallet: wallet_info
        };
        let wallet_holder3: WalletHolder = WalletHolder {
            owner: owner3,
            owner_id: 3u8,
            wallet: wallet_info
        };

        return (wallet_holder1, wallet_holder2, wallet_holder3) then finalize(wallet_id);
    }

    finalize create_wallet3(wallet_id: field) {
        // ensure uniqueness
        assert(!Mapping::get_or_use(wallet_exists, wallet_id, false));
        Mapping::set(wallet_exists, wallet_id, true);
    }

    transition create_transfer3(wallet_holder: WalletHolder, token_id: u64, amount: u128, to_address: address, to_wallet_id: field, transfer_id: field) -> (WalletHolder, PendingTransfer, PendingTransfer, PendingTransfer) {
        let holder_count: u8 = 3u8;
        let zero_address: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;

        assert(wallet_holder.wallet.holder_count == holder_count);
        assert(to_address == zero_address || to_wallet_id == 0field);

        let pending1: PendingTransfer = PendingTransfer {
            owner: wallet_holder.wallet.holder1,
            transfer_id: transfer_id,
            creator: wallet_holder.owner,
            wallet: wallet_holder.wallet,
            token_id: token_id,
            amount: amount,
            to_address: to_address,
            to_wallet_id: to_wallet_id
        };

        let pending2: PendingTransfer = PendingTransfer {
            owner: wallet_holder.wallet.holder2,
            transfer_id: transfer_id,
            creator: wallet_holder.owner,
            wallet: wallet_holder.wallet,
            token_id: token_id,
            amount: amount,
            to_address: to_address,
            to_wallet_id: to_wallet_id
        };

        let pending3: PendingTransfer = PendingTransfer {
            owner: wallet_holder.wallet.holder3,
            transfer_id: transfer_id,
            creator: wallet_holder.owner,
            wallet: wallet_holder.wallet,
            token_id: token_id,
            amount: amount,
            to_address: to_address,
            to_wallet_id: to_wallet_id
        };

        let new_wallet_holder: WalletHolder = WalletHolder {
            owner: wallet_holder.owner,
            owner_id: wallet_holder.owner_id,
            wallet: wallet_holder.wallet
        };

        return (new_wallet_holder, pending1, pending2, pending3) then finalize(transfer_id);
    }

    finalize create_transfer3(transfer_id: field) {
        assert(!Mapping::contains(transfers, transfer_id));
        Mapping::set(transfers, transfer_id, TransferStatus {
            confirmation_count: 1u8,
            rejection_count: 0u8,
            status: 0u8,
        });
    }

    transition confirm_transfer(pending_transfer: PendingTransfer) -> SignedTransfer {
        let signed: SignedTransfer = SignedTransfer {
            owner: pending_transfer.owner,
            transfer_id: pending_transfer.transfer_id,
            creator: pending_transfer.creator,
            wallet: pending_transfer.wallet,
            token_id: pending_transfer.token_id,
            amount: pending_transfer.amount,
            to_address: pending_transfer.to_address,
            to_wallet_id: pending_transfer.to_wallet_id,
            confirmed: true
        };

        return (signed) then finalize(pending_transfer.transfer_id);
    }

    finalize confirm_transfer(transfer_id: field) {
        let transfer_status: TransferStatus = Mapping::get(transfers, transfer_id);

        // Confirming doesn't change the status of the tx
        // A wallet holder can sign created, sent or even rejected tx and his vote will be counted.
        // Later an optimized transition like 'confirm_and_execute' can be created
        Mapping::set(transfers, transfer_id, TransferStatus {
            confirmation_count: transfer_status.confirmation_count + 1u8,
            rejection_count: transfer_status.rejection_count,
            status: transfer_status.status
        });
    }

    transition reject_transfer(pending_transfer: PendingTransfer) -> SignedTransfer {
        let signed: SignedTransfer = SignedTransfer {
            owner: pending_transfer.owner,
            transfer_id: pending_transfer.transfer_id,
            creator: pending_transfer.creator,
            wallet: pending_transfer.wallet,
            token_id: pending_transfer.token_id,
            amount: pending_transfer.amount,
            to_address: pending_transfer.to_address,
            to_wallet_id: pending_transfer.to_wallet_id,
            confirmed: false
        };

        return (signed) then finalize(pending_transfer.transfer_id);
    }

    finalize reject_transfer(transfer_id: field) {
        let transfer_status: TransferStatus = Mapping::get(transfers, transfer_id);
        Mapping::set(transfers, transfer_id, TransferStatus {
            confirmation_count: transfer_status.confirmation_count,
            rejection_count: transfer_status.rejection_count + 1u8,
            status: transfer_status.status
        });
    }

    transition execute_confirmed_transfer(signed_transfer: SignedTransfer) -> (SignedTransfer, Token) {
        let zero_address: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;
        assert(signed_transfer.to_wallet_id == 0field || signed_transfer.to_address == zero_address);

        let token: Token = Token {
            owner: signed_transfer.to_address,
            amount: signed_transfer.to_wallet_id == 0field ? signed_transfer.amount : 0u128,
            token_id: signed_transfer.token_id
        };
        let to_wallet_balance_key: field = signed_transfer.to_wallet_id == 0field ? 0field : get_wallet_balance_key(token.token_id, signed_transfer.to_wallet_id);

        let new_signed: SignedTransfer = SignedTransfer {
            owner: signed_transfer.owner,
            transfer_id: signed_transfer.transfer_id,
            creator: signed_transfer.creator,
            wallet: signed_transfer.wallet,
            token_id: signed_transfer.token_id,
            amount: signed_transfer.amount,
            to_address: signed_transfer.to_address,
            to_wallet_id: signed_transfer.to_wallet_id,
            confirmed: signed_transfer.confirmed
        };
        return (new_signed, token) then finalize(signed_transfer.transfer_id, signed_transfer.wallet.threshold, get_wallet_balance_key(token.token_id, signed_transfer.wallet.wallet_id), signed_transfer.amount, to_wallet_balance_key);
    }

    finalize execute_confirmed_transfer(transfer_id: field, wallet_threshold: u8, wallet_balance_key: field, amount: u128, to_wallet_balance_key: field) {
        let transfer_status: TransferStatus = Mapping::get(transfers, transfer_id);
        // check that the transfer is not executed yet
        assert(transfer_status.status == 0u8); 
        // check that we reached the threshold in confirmation votes
        assert(transfer_status.confirmation_count >= wallet_threshold);

        let balance: u128 = Mapping::get(wallet_balances, wallet_balance_key);
        // decrease wallet balance, minus will throw if balance < amount
        Mapping::set(wallet_balances, wallet_balance_key, balance - amount);
        if (to_wallet_balance_key == 0field) {
            // The token has already been issued in the transition
        } else {
            let to_balance: u128 = Mapping::get_or_use(wallet_balances, to_wallet_balance_key, 0u128);
            Mapping::set(wallet_balances, to_wallet_balance_key, to_balance + amount);
        }

        Mapping::set(transfers, transfer_id, TransferStatus { 
            confirmation_count: transfer_status.confirmation_count,
            rejection_count: transfer_status.rejection_count,
            status: 1u8
        });
    }

    transition deposit(token: Token, amount: u128, wallet_id: field) -> (Token) {
        let change: Token = Token {
            owner: token.owner,
            amount: token.amount - amount,
            token_id: token.token_id,
        };

        return (change) then finalize(wallet_id, get_wallet_balance_key(token.token_id, wallet_id), amount);
    }

    finalize deposit(wallet_id: field, wallet_balance_key: field, amount: u128) {
        assert (Mapping::contains(wallet_exists, wallet_id));

        let balance: u128 = Mapping::get_or_use(wallet_balances, wallet_balance_key, 0u128);
        Mapping::set(wallet_balances, wallet_balance_key, balance + amount);
    }

    inline get_wallet_balance_key(token_id: u64, wallet_id: field) -> field {
        return BHP256::hash_to_field(WalletBalanceKey {token_id: token_id, wallet_id: wallet_id});
    }

    
    // ██████████████████████████████████████████████████████████████████████
    //                                 Tokens
    // ██████████████████████████████████████████████████████████████████████

    record Token {
        owner: address,
        amount: u128,
        token_id: u64,
    }

    struct TokenInfo {
        token_id: u64,
        max_supply: u128,
        decimals: u8,
    }

    mapping registered_tokens: u64 => TokenInfo;

    transition create_token(token_id: u64, decimals: u8, max_supply: u128) {
        let new_token: TokenInfo = TokenInfo{
            token_id,
            decimals,
            max_supply,
        };
        return then finalize(new_token);
    }

    finalize create_token(new_token: TokenInfo) {
        assert(!Mapping::contains(registered_tokens, new_token.token_id));
        Mapping::set(registered_tokens, new_token.token_id, new_token);    
    }

    transition mint_private(
        receiver: address, 
        token_id: u64, 
        amount: u128,
    ) -> Token {
        assert(amount <= 1000u128 * (10u128 ** 6u8));
        return Token {
            owner: receiver,
            amount: amount,
            token_id,
        } then finalize(token_id);        
    }

    finalize mint_private(token_id: u64) {
        let token_info: TokenInfo = Mapping::get(registered_tokens, token_id);
    }

}
