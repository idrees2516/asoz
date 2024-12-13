use core::traits::Into;
use core::option::OptionTrait;
use core::array::ArrayTrait;
use starknet::ContractAddress;

#[derive(Drop, Serde)]
struct PriceData {
    token: ContractAddress,
    price: u256,
    timestamp: u64,
    source: felt252,
    signature: Array<felt252>
}

#[derive(Drop, Serde)]
struct OracleConfig {
    min_sources: u32,
    max_staleness: u64,
    price_deviation_threshold: u256,
    validators: Array<ContractAddress>
}

trait OracleTrait {
    fn initialize(config: OracleConfig) -> OracleConfig;
    fn update_price(ref self: OracleConfig, data: PriceData) -> Result<(), felt252>;
    fn get_price(ref self: OracleConfig, token: ContractAddress) -> Result<u256, felt252>;
    fn add_validator(ref self: OracleConfig, validator: ContractAddress) -> Result<(), felt252>;
    fn remove_validator(ref self: OracleConfig, validator: ContractAddress) -> Result<(), felt252>;
}

impl OracleImplementation of OracleTrait {
    fn initialize(config: OracleConfig) -> OracleConfig {
        assert(config.min_sources > 0, 'Invalid min sources');
        assert(config.max_staleness > 0, 'Invalid max staleness');
        assert(
            config.price_deviation_threshold > 0,
            'Invalid deviation threshold'
        );
        assert(config.validators.len() > 0, 'No validators');
        
        config
    }
    
    fn update_price(
        ref self: OracleConfig,
        data: PriceData
    ) -> Result<(), felt252> {
        // Validate timestamp
        let current_time = starknet::get_block_timestamp();
        if data.timestamp + self.max_staleness < current_time {
            return Result::Err('Price data too old');
        }
        
        // Validate source
        if !is_valid_source(data.source) {
            return Result::Err('Invalid price source');
        }
        
        // Verify signature
        if !verify_price_signature(data) {
            return Result::Err('Invalid signature');
        }
        
        // Check price deviation
        let current_price = get_stored_price(data.token)?;
        let deviation = calculate_deviation(
            current_price,
            data.price
        );
        
        if deviation > self.price_deviation_threshold {
            return Result::Err('Price deviation too high');
        }
        
        // Store price data
        store_price_data(data);
        
        Result::Ok(())
    }
    
    fn get_price(
        ref self: OracleConfig,
        token: ContractAddress
    ) -> Result<u256, felt252> {
        // Get all recent price data
        let price_data = get_recent_price_data(
            token,
            self.max_staleness
        )?;
        
        // Check minimum sources
        if price_data.len() < self.min_sources {
            return Result::Err('Insufficient price sources');
        }
        
        // Calculate median price
        let median = calculate_median_price(price_data);
        
        Result::Ok(median)
    }
    
    fn add_validator(
        ref self: OracleConfig,
        validator: ContractAddress
    ) -> Result<(), felt252> {
        // Check if validator already exists
        if is_validator(self.validators, validator) {
            return Result::Err('Validator exists');
        }
        
        // Add validator
        self.validators.append(validator);
        
        Result::Ok(())
    }
    
    fn remove_validator(
        ref self: OracleConfig,
        validator: ContractAddress
    ) -> Result<(), felt252> {
        // Find and remove validator
        let mut found = false;
        let mut i = 0;
        
        while i < self.validators.len() {
            if self.validators[i] == validator {
                self.validators.pop_front();
                found = true;
                break;
            }
            i += 1;
        }
        
        if !found {
            return Result::Err('Validator not found');
        }
        
        // Check minimum validators
        if self.validators.len() < self.min_sources {
            return Result::Err('Too few validators');
        }
        
        Result::Ok(())
    }
}

// Helper functions
fn is_valid_source(source: felt252) -> bool {
    // Implement source validation
    true
}

fn verify_price_signature(data: PriceData) -> bool {
    // Implement signature verification
    true
}

fn get_stored_price(
    token: ContractAddress
) -> Result<u256, felt252> {
    // Implement price retrieval
    Result::Ok(0)
}

fn calculate_deviation(
    price1: u256,
    price2: u256
) -> u256 {
    if price1 > price2 {
        price1 - price2
    } else {
        price2 - price1
    }
}

fn store_price_data(data: PriceData) {
    // Implement price storage
}

fn get_recent_price_data(
    token: ContractAddress,
    max_age: u64
) -> Result<Array<PriceData>, felt252> {
    // Implement recent price data retrieval
    Result::Ok(ArrayTrait::new())
}

fn calculate_median_price(
    price_data: Array<PriceData>
) -> u256 {
    let mut prices = ArrayTrait::new();
    let mut i = 0;
    
    // Extract prices
    while i < price_data.len() {
        prices.append(price_data[i].price);
        i += 1;
    }
    
    // Sort prices
    i = 0;
    while i < prices.len() {
        let mut j = i + 1;
        while j < prices.len() {
            if prices[j] < prices[i] {
                let temp = prices[i];
                prices[i] = prices[j];
                prices[j] = temp;
            }
            j += 1;
        }
        i += 1;
    }
    
    // Return median
    prices[prices.len() / 2]
}

fn is_validator(
    validators: Array<ContractAddress>,
    validator: ContractAddress
) -> bool {
    let mut i = 0;
    while i < validators.len() {
        if validators[i] == validator {
            return true;
        }
        i += 1;
    }
    false
}
