module projectOwnerAdr::BlindBoxContract_Crystara_TestV1 {
    
    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    use std::error;
    use std::option::{Self, Option};
    use supra_framework::account::{Self, SignerCapability};
    use supra_framework::supra_account;
    use aptos_token::token;
    use supra_framework::event;
    use supra_framework::timestamp;
    use supra_framework::guid::GUID;

    /// Error Codes
    /// Action not authorized because the signer is not the admin of this module
    const ENOT_AUTHORIZED: u64 = 1;

    /// Market Settings
    use projectOwnerAdr::BlindBoxAdminContract_Crystara_TestV1::get_resource_address as adminResourceAddressSettings;
    
    //Event Types

    //Entry Functions
    
    // https://github.com/Entropy-Foundation/aptos-core/blob/dev/aptos-move/framework/aptos-token/sources/token.move#L1103
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

      let mutability_settings = vector::empty<bool>();
      vector::push_back(&mut mutability_settings , true); //Description
      vector::push_back(&mut mutability_settings , true); //URI
      vector::push_back(&mut mutability_settings , true); //Maximum
  
      // Create the collection using the new standard
      token::create_collection(
          source_account,
          collection_name_str,
          description_str,
          collection_uri_str,
          maximum_supply,
          mutability_settings

      );
    }

    #[view]
    public fun check_collection_exists(creator:: address, collection_name: vector<v8>) {
        let exists = token::check_collection_exists(creator, string::utf8(collection_name))
    }    
   

}