use core::traits::Into;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use starknet::ContractAddress;

#[derive(Drop, Serde)]
struct Transaction {
    id: u256,
    sender: ContractAddress,
    inputs: Array<u256>,
    outputs: Array<u256>,
    fee: u256,
    timestamp: u64,
    status: felt252
}

#[derive(Drop, Serde)]
struct TransactionPool {
    transactions: Array<Transaction>,
    fee_threshold: u256,
    max_size: usize,
    min_fee: u256,
    dynamic_fee_rate: u256
}

trait TransactionPoolTrait {
    fn new(
        fee_threshold: u256,
        max_size: usize,
        min_fee: u256,
        dynamic_fee_rate: u256
    ) -> TransactionPool;
    
    fn add_transaction(
        ref self: TransactionPool,
        transaction: Transaction
    ) -> Result<(), felt252>;
    
    fn remove_transaction(
        ref self: TransactionPool,
        transaction_id: u256
    ) -> Result<(), felt252>;
    
    fn get_next_batch(
        ref self: TransactionPool,
        max_size: usize
    ) -> Array<Transaction>;
    
    fn update_fee_parameters(
        ref self: TransactionPool,
        pool_size: usize
    );
    
    fn clean_expired_transactions(
        ref self: TransactionPool,
        current_time: u64
    );
}

impl TransactionPoolImplementation of TransactionPoolTrait {
    fn new(
        fee_threshold: u256,
        max_size: usize,
        min_fee: u256,
        dynamic_fee_rate: u256
    ) -> TransactionPool {
        TransactionPool {
            transactions: ArrayTrait::new(),
            fee_threshold,
            max_size,
            min_fee,
            dynamic_fee_rate
        }
    }
    
    fn add_transaction(
        ref self: TransactionPool,
        transaction: Transaction
    ) -> Result<(), felt252> {
        // Validate transaction
        if !validate_transaction(transaction) {
            return Result::Err('Invalid transaction');
        }
        
        // Check pool size
        if self.transactions.len() >= self.max_size {
            return Result::Err('Pool full');
        }
        
        // Check minimum fee
        if transaction.fee < self.min_fee {
            return Result::Err('Fee too low');
        }
        
        // Add transaction
        self.transactions.append(transaction);
        
        // Sort by fee
        sort_transactions_by_fee(ref self.transactions);
        
        Result::Ok(())
    }
    
    fn remove_transaction(
        ref self: TransactionPool,
        transaction_id: u256
    ) -> Result<(), felt252> {
        let mut found = false;
        let mut i = 0;
        
        while i < self.transactions.len() {
            if self.transactions[i].id == transaction_id {
                self.transactions.pop_front();
                found = true;
                break;
            }
            i += 1;
        }
        
        if !found {
            return Result::Err('Transaction not found');
        }
        
        Result::Ok(())
    }
    
    fn get_next_batch(
        ref self: TransactionPool,
        max_size: usize
    ) -> Array<Transaction> {
        let mut batch = ArrayTrait::new();
        let mut size = 0;
        let mut i = 0;
        
        while i < self.transactions.len() && size < max_size {
            let transaction = self.transactions[i];
            if transaction.fee >= self.fee_threshold {
                batch.append(transaction);
                size += 1;
            }
            i += 1;
        }
        
        batch
    }
    
    fn update_fee_parameters(
        ref self: TransactionPool,
        pool_size: usize
    ) {
        // Update minimum fee based on pool utilization
        let utilization = pool_size * 100 / self.max_size;
        if utilization > 80 {
            self.min_fee = self.min_fee * (100 + self.dynamic_fee_rate) / 100;
        } else if utilization < 20 {
            self.min_fee = self.min_fee * 100 / (100 + self.dynamic_fee_rate);
        }
        
        // Update fee threshold
        self.fee_threshold = calculate_fee_threshold(
            self.transactions,
            pool_size
        );
    }
    
    fn clean_expired_transactions(
        ref self: TransactionPool,
        current_time: u64
    ) {
        let mut i = 0;
        while i < self.transactions.len() {
            if is_transaction_expired(
                self.transactions[i],
                current_time
            ) {
                self.transactions.pop_front();
            }
            i += 1;
        }
    }
}

// Helper functions
fn validate_transaction(transaction: Transaction) -> bool {
    // Validate basic parameters
    if transaction.inputs.len() == 0 || transaction.outputs.len() == 0 {
        return false;
    }
    
    // Validate amounts
    let total_in = sum_array(transaction.inputs);
    let total_out = sum_array(transaction.outputs);
    if total_in != total_out + transaction.fee {
        return false;
    }
    
    // Validate timestamp
    if transaction.timestamp > starknet::get_block_timestamp() {
        return false;
    }
    
    true
}

fn sort_transactions_by_fee(ref transactions: Array<Transaction>) {
    // Implement sorting logic (e.g., bubble sort)
    let mut i = 0;
    while i < transactions.len() {
        let mut j = 0;
        while j < transactions.len() - i - 1 {
            if transactions[j].fee < transactions[j + 1].fee {
                // Swap transactions
                let temp = transactions[j];
                transactions[j] = transactions[j + 1];
                transactions[j + 1] = temp;
            }
            j += 1;
        }
        i += 1;
    }
}

fn calculate_fee_threshold(
    transactions: Array<Transaction>,
    pool_size: usize
) -> u256 {
    if pool_size == 0 {
        return 0;
    }
    
    // Calculate median fee of recent transactions
    let mut fees = ArrayTrait::new();
    let mut i = 0;
    while i < transactions.len() {
        fees.append(transactions[i].fee);
        i += 1;
    }
    
    sort_array(ref fees);
    fees[fees.len() / 2]
}

fn is_transaction_expired(
    transaction: Transaction,
    current_time: u64
) -> bool {
    // Transaction expires after 1 hour
    current_time > transaction.timestamp + 3600
}

fn sum_array(arr: Array<u256>) -> u256 {
    let mut sum = 0;
    let mut i = 0;
    while i < arr.len() {
        sum += arr[i];
        i += 1;
    }
    sum
}

fn sort_array(ref arr: Array<u256>) {
    let mut i = 0;
    while i < arr.len() {
        let mut j = 0;
        while j < arr.len() - i - 1 {
            if arr[j] > arr[j + 1] {
                let temp = arr[j];
                arr[j] = arr[j + 1];
                arr[j + 1] = temp;
            }
            j += 1;
        }
        i += 1;
    }
}
