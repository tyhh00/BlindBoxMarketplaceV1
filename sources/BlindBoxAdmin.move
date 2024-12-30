module projectOwnerAdr::BlindBoxAdminContract {
    //Generic Imports
    use std::signer;
    use std::vector;
    use std::string;
    use std::error;
    use std::option::{Self, Option};

    //Supra Framework Imports
    use supra_framework::account::{Self, SignerCapability};
    use supra_framework::supra_account;

    //Definitions
    const RESOURCE_SEED: vector<u8> = b"PlatformFee"; // This could be any seed

    //Errors
    const YOU_ARE_NOT_PROJECT_OWNER: u64 = 1;

    public struct Decimal {
        value: u64,  // The scaled integer value
        scale: u8,   // Number of decimal places
    }

    struct PlatformFeeSettings has key {
        blindbox_platformFee_Percent: Decimal,
        
        nft_totalRoyalty_Percent: Decimal,
        nft_RoyaltiesToCreator_Percent: Decimal,
        nft_RoyaltiesToPlatform_Percent: Decimal,

        signer_cap: SignerCapability,
    }
    
    fun init_module(owner_signer: &signer) {
        assert!(signer::address_of(owner_signer) == @projectOwnerAdr, error::unauthenticated(YOU_ARE_NOT_PROJECT_OWNER));
        let (resource_signer, signer_cap) = account::create_resource_account(owner_signer, RESOURCE_SEED);
        let platformFeeSettings = PlatformFeeSettings {
            blindbox_platformFee_Percent: Decimal{value:5 , scale:2},
            nft_totalRoyalty_Percent: Decimal{value:5 , scale:2},
            nft_RoyaltiesToCreator_Percent: Decimal{value:75 , scale:2},
            nft_RoyaltiesToPlatform_Percent: Decimal{value:25 , scale:2},
            signer_cap,
        };
        move_to(&resource_signer, platformFeeSettings);
    }

    #[view]
    /// Get resource account address
    fun get_resource_address(): address {
        account::create_resource_address(&@projectOwnerAdr, RESOURCE_SEED)
    }



    //Utils

    /// Creates a Decimal value
    public fun decimal_create(value: u64, scale: u8): Decimal {
        Decimal { value, scale }
    }

    /// Converts a Decimal back to its floating-point representation as a string
    public fun decimal_to_string(decimal: &Decimal): string {
        let divisor = pow(10, decimal.scale);
        let integer_part = decimal.value / divisor;
        let fractional_part = decimal.value % divisor;
        string::concat(
            string::concat(integer_part, b"."),
            fractional_part
        )
    }

    /// Adds two Decimal values
    public fun decimal_add(dec1: &Decimal, dec2: &Decimal): Decimal {
        assert!(dec1.scale == dec2.scale, 1);  // Ensure both decimals have the same scale
        let sum = dec1.value + dec2.value;
        Decimal { value: sum, scale: dec1.scale }
    }

    /// Subtracts two Decimal values
    public fun decimal_subtract(dec1: &Decimal, dec2: &Decimal): Decimal {
        assert!(dec1.scale == dec2.scale, 1);  // Ensure both decimals have the same scale
        let difference = dec1.value - dec2.value;
        Decimal { value: difference, scale: dec1.scale }
    }

    /// Multiplies two Decimal values
    public fun decimal_multiply(dec1: &Decimal, dec2: &Decimal): Decimal {
        assert!(dec1.scale == dec2.scale, 1);  // Ensure both decimals have the same scale
        let product = (dec1.value * dec2.value) / pow(10, dec1.scale);
        Decimal { value: product, scale: dec1.scale }
    }

    /// Divides two Decimal values
    public fun decimal_divide(dec1: &Decimal, dec2: &Decimal): Decimal {
        assert!(dec1.scale == dec2.scale, 1);  // Ensure both decimals have the same scale
        let quotient = (dec1.value * pow(10, dec1.scale)) / dec2.value;
        Decimal { value: quotient, scale: dec1.scale }
    }

    /// Helper function to compute powers of 10
    fun pow(base: u64, exponent: u8): u64 {
        let result = 1;
        let count = 0;
        while (count < exponent) {
            result = result * base;
            count = count + 1;
        };
        result
    }

}