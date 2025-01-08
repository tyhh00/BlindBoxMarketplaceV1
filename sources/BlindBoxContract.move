module projectOwnerAdr::BlindBoxContract {
    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    use std::error;
    use std::option::{Self, Option};
    use supra_framework::account::{Self, SignerCapability};
    use supra_framework::supra_account;
    use aptos_token_objects::aptos_token as token;

    //use supra_addr::supra_vrf; //Not whitelisted yet
    use projectOwnerAdr::BlindBoxAdminContract::get_resource_address as adminResourceAddressSettings;


    /// Action not authorized because the signer is not the admin of this module
    const ENOT_AUTHORIZED: u64 = 1;

    /// `init_module` is automatically called when publishing the module.
    /// In this function, we create an example NFT collection and an example token.
    public entry fun create_collection(
    source_account: &signer,
    collection_name: vector<u8>,
    description: vector<u8>,
    collection_uri: vector<u8>,
    token_name: vector<u8>,
    maximum_supply: u64,
    token_uri: vector<u8>
) {
    // Convert the vectors to strings
    let collection_name_str = string::utf8(collection_name);
    let description_str = string::utf8(description);
    let collection_uri_str = string::utf8(collection_uri);
    let token_name_str = string::utf8(token_name);
    let token_uri_str = string::utf8(token_uri);

    // Define mutable settings
    let mutable_description = false;
    let mutable_royalty = false;
    let mutable_uri = false;
    let mutable_token_description = false;
    let mutable_token_name = false;
    let mutable_token_properties = false;
    let mutable_token_uri = false;

    // Define burn and freeze permissions for creator
    let tokens_burnable_by_creator = false;
    let tokens_freezable_by_creator = false;

    // Define royalty settings (10% royalty)
    let royalty_numerator = 10;
    let royalty_denominator = 100;

    // Create the collection using the new standard
    create_collection(
        source_account,
        description_str,
        maximum_supply,
        collection_name_str,
        collection_uri_str,
        mutable_description,
        mutable_royalty,
        mutable_uri,
        mutable_token_description,
        mutable_token_name,
        mutable_token_properties,
        mutable_token_uri,
        tokens_burnable_by_creator,
        tokens_freezable_by_creator,
        royalty_numerator,
        royalty_denominator
    );

    // Example of creating token data (metadata) for the NFT
    let token_data_id = create_tokendata(
        source_account,
        collection_name_str,
        token_name_str,
        string::utf8(b"Token description"), // Token description
        0,                                 // Initial amount (can be adjusted later)
        token_uri_str,
        signer::address_of(source_account),
        1,                                 // Royalty percentage (1% in this case)
        0,                                 // Maximum supply (0 means unlimited)
        create_token_mutability_config(
            &vector<bool>[false, false, false, false, true]  // Mutability configuration
        ),
        vector<String>[string::utf8(b"given_to")],
        vector<vector<u8>>[b""],
        vector<String>[string::utf8(b"address")]
    );

    // Optionally move token data to the creator's account if needed
    move_to(source_account, token_data_id);
}





}

