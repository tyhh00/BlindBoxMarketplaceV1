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

    //Custom Imports
    use projectOwnerAdr::DecimalUtils as DecimalUtils;

    //Definitions
    const RESOURCE_SEED: vector<u8> = b"PlatformFee"; // This could be any seed

    //Errors
    const YOU_ARE_NOT_PROJECT_OWNER: u64 = 1;

    struct PlatformFeeSettings has key {
        blindbox_platformFee_Percent: DecimalUtils::Decimal,
        
        nft_totalRoyalty_Percent: u256,
        nft_RoyaltiesToCreator_Percent: u64,
        nft_RoyaltiesToPlatform_Percent: u64,

        signer_cap: SignerCapability,
    }
    
    fun init_module(owner_signer: &signer) {
        assert!(signer::address_of(owner_signer) == @projectOwnerAdr, error::unauthenticated(YOU_ARE_NOT_PROJECT_OWNER));
        let (resource_signer, signer_cap) = account::create_resource_account(owner_signer, RESOURCE_SEED);
        let platformFeeSettings = PlatformFeeSettings {
            blindbox_platformFee_Percent: Decimal(5 , 2),
            nft_totalRoyalty_Percent: Decimal(5 , 2),
            nft_RoyaltiesToCreator_Percent: Decimal(75, 2),
            nft_RoyaltiesToPlatform_Percent: Decimal(25, 2),
            signer_cap,
        };
        move_to(&resource_signer, platformFeeSettings);
    }

    #[view]
    /// Get resource account address
    fun get_resource_address(): address {
        account::create_resource_address(&@projectOwnerAdr, RESOURCE_SEED)
    }

}