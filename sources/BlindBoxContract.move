module projectOwnerAdr::BlindBoxContract_Crystara_TestV1 {
    
    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    use std::error;
    use std::option::{Self, Option};
    use supra_framework::account::{Self, SignerCapability};
    use supra_framework::supra_account;
    use aptos_token_objects::aptos_token;
    use supra_framework::event;
    use supra_framework::timestamp;
    use supra_framework::guid::GUID;

    /// Error Codes
    /// Action not authorized because the signer is not the admin of this module
    const ENOT_AUTHORIZED: u64 = 1;

    /// Market Settings
    use projectOwnerAdr::BlindBoxAdminContract_Crystara_TestV1::get_resource_address as adminResourceAddressSettings;
    
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
      aptos_token::create_collection(
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
        let account_addr = signer::address_of(source_account);

        // Create the collection creation event
        let new_event = CollectionCreatedEvent {
            creator: account_addr,
            collection_name: collection_name,
            metadata_uri: collection_uri,
            timestamp: timestamp::now_microseconds(), 
        };

        // Emit the event
        event::emit(new_event);

      // Example of creating token data (metadata) for the NFT
      /*aptos_token::mint(
          source_account,
          collection_name_str,
          string::utf8(b"Token description"), // Token description
          token_name_str,                             
          token_uri_str, 
          vector<String>[string::utf8(b"given_to")],
          vector<String>[string::utf8(b"address")],
          vector<vector<u8>>[b""],
      );*/

    }

    // Event struct to capture collection creation
    #[event]
    struct CollectionCreatedEvent has copy, drop, store {
        creator: address,  // Address of the creator
        collection_name: vector<u8>,  // Name of the collection
        metadata_uri: vector<u8>,  // Metadata URI
        timestamp: u64,  // Block timestamp
    }

    
   

}