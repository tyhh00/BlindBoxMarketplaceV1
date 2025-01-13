module projectOwnerAdr::BlindBoxContract_Crystara_TestV1 {
    
    use std::signer;
    use std::vector;
    use std::string::{Self, String};
    use std::error;
    use std::table;
    ///use std::option::{Self, Option};
    use supra_framework::account::{Self, SignerCapability};
    use supra_framework::supra_account;
    use aptos_token::token;
    use supra_framework::coin::{Self, Coin};
    use supra_framework::event;
    use supra_framework::timestamp;
    use supra_framework::guid::GUID;

    /// Error Codes
    /// Action not authorized because the signer is not the admin of this module
    const ENOT_AUTHORIZED: u64 = 1;
    /// Collection already exists
    const ECOLLECTION_EXISTS: u64 = 2;
    const EINSUFFICIENT_BALANCE: u64 = 3;
    const ELOOTBOX_NOT_FOUND: u64 = 4;
    const ENOT_ENOUGH_STOCK: u64 = 5;
    const ELOOTBOX_EXISTS: u64 = 6;
    const EMAX_ROLLS_REACHED: u64 = 7;

    // Market Settings
    //use projectOwnerAdr::BlindBoxAdminContract_Crystara_TestV1::get_resource_address as adminResourceAddressSettings;
    
    //Event Types
    #[event]
    struct CollectionCreatedEvent has copy, drop, store {
        creator: address,  // Address of the creator
        collection_name: vector<u8>,  // Name of the collection
        metadata_uri: vector<u8>,  // Metadata URI
        timestamp: u64,  // Block timestamp
    }

    #[event]
    struct LootboxCreatedEvent has copy, drop, store {
        creator: address,
        collection_name: vector<u8>,
        price: u64,
        price_coinType: String,
        timestamp: u64,
    }

    //Structs
    
    struct Lootbox has store {
      creator: address,
      collectionName: String, // Used to access collection by Creator + CollName in aptos_token::token
      // ^ As good as storing the "Collection" Object because thats all we need to access it
      rarities: table::Table<String, u64>, // Map rarity name to weight
      rarities_showItemWhenRoll: table::Table<String, bool>,
      
      stock: u64, //Available stock
      maxRolls: u64, //Maximum Rolls ever
      rolled: u64, //Amount of this lootbox that has been rolled
      
      whitelistMode: bool,
      allow_mintList: table::Table<address, u64>,
      price: FixedPriceListing<CoinType>,
      
      requiresKey: bool,
      keysCollectionName: String,
      
      tokensInLootbox: vector<String>, //Token Data IDs involved
    }

    /// Table to store all lootboxes by creator and collection name
    struct Lootboxes has key {
        lootbox_table: table::Table<String, Lootbox>, // Key: collection_name
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct FixedPriceListing<phantom CoinType> has key, store {
        /// The price to purchase the item up for listing.
        price: u64,
    }

    //Entry Functions
    
    // https://github.com/Entropy-Foundation/aptos-core/blob/dev/aptos-move/framework/aptos-token/sources/token.move#L1103
    public entry fun create_lootbox<CoinType>(
      source_account: &signer,
      collection_name: vector<u8>,
      description: vector<u8>,
      collection_uri: vector<u8>,
      maximum_supply: u64,
      initial_stock: u64,
      max_stock: u64,
      price: u64,

      requiresKey: bool,
      keys_collection_name: vector<u8>,
      keys_collection_description: vector<u8>,
      keys_collection_url: vector<u8>,
    ) {
      let account_addr = signer::address_of(source_account);

      //Check if Underlying Collection Name was used before
      assert!(
        !token::check_collection_exists(account_addr, string::utf8(collection_name))
        , 
        error::not_found(ECOLLECTION_EXISTS)
      );

      //Check if Lootboxes Table Exists for Creator, If No, Init Table.
      if (!exists<Lootboxes>(account_addr)) {
        move_to(source_account, Lootboxes {
            lootbox_table: table::new<String, Lootbox>(),
        });
      };
      
      // Convert the vectors to strings
      let collection_name_str = string::utf8(collection_name);
      let description_str = string::utf8(description);
      let collection_uri_str = string::utf8(collection_uri);

      let lootboxes = borrow_global_mut<Lootboxes>(account_addr);
      assert!(
        !table::contains(&lootboxes.lootbox_table, collection_name_str),
        error::already_exists(ELOOTBOX_EXISTS)
      );

      let fixed_price_listing = FixedPriceListing<CoinType> {
            price,
        };

      let new_lootbox = Lootbox {
        creator: account_addr,
        collectionName: collection_name_str,

        rarities: table::new<String, u64>(),
        rarities_showItemWhenRoll: table::new<String, bool>(),

        stock: initial_stock,
        maxRolls: max_stock,
        rolled: 0,

        whitelistMode: true,
        allow_mintList: table::new<address, u64>(),

        price: fixed_price_listing,

        requiresKey: requiresKey,
        keysCollectionName: string::utf8(keys_collection_name),

        tokensInLootbox: vector::empty<String>(),
      };


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

      //TODO if need key, create key collection
      
      let lootbox_event = LootboxCreatedEvent {
        creator: account_addr,
        collection_name: collection_name,
        price: price,
        price_coinType: string::utf8(b"TODO: This is not done yet cuz chains dont store these info at runtime"),
        timestamp: timestamp::now_microseconds(), 
      };
      event::emit(lootbox_event);

      // Create the collection creation event
      let new_event = CollectionCreatedEvent {
            creator: account_addr,
            collection_name: collection_name,
            metadata_uri: collection_uri,
            timestamp: timestamp::now_microseconds(), 
        };
        // Emit the event
      event::emit(new_event);
    }


    //Wop
    public entry fun set_rarities(
      collection_owner: &signer,
      lootbox_name: vector<u8>,

    ) {

    }

    public entry fun add_tokenMetaData(

    ){

    }

    public entry fun modify_tokenMetaData(
      tokenId: vector<u8>,
    ){

    }

    /// Purchase a lootbox
    public entry fun purchase_lootbox<CoinType>(
        buyer: &signer,
        creator_addr: address,
        collection_name: vector<u8>
      ) {
        let buyer_addr = signer::address_of(buyer);
        let collection_name_str = string::utf8(collection_name);

        // Fetch the lootbox
        let lootboxes = borrow_global_mut<Lootboxes>(creator_addr);
        let lootbox = table::borrow_mut(&mut lootboxes.lootbox_table, collection_name_str);
        assert!(lootbox.stock > 0, error::not_found(ENOT_ENOUGH_STOCK));
        assert!(lootbox.maxRolls < lootbox.rolled, error::not_found(EMAX_ROLLS_REACHED) );

        // Check buyer's balance
        let buyer_balance = coin::balance<CoinType>(buyer_addr);
        assert!(buyer_balance >= lootbox.price.price, error::invalid_argument(EINSUFFICIENT_BALANCE));

        // Deduct payment from the buyer
        let mut coins = coin::withdraw<CoinType>(buyer, lootbox.price.price);

        // Distribute payment
        let marketplace_cut = lootbox.price.price / 10; // 10%
        let creator_cut = lootbox.price.price - marketplace_cut; // 90%

        let marketplace_extracted_coins = coin::extract<CoinType>(coins, marketplace_cut);
        supra_account::deposit_coins(lootbox.creator, coins);
        supra_account::deposit_coins(@projectOwnerAdr, marketplace_extracted_coins);

        // Update lootbox state
        lootbox.stock = lootbox.stock - 1;
        lootbox.rolled = lootbox.rolled + 1;

        // RNG logic placeholder
        // TODO: Implement random number generation and token assignment.
    }

    /* For token creation
      // Define mutable settings
      let mutable_description = true;
      let mutable_royalty = true;
      let mutable_uri = true;
      let mutable_token_description = true;
      let mutable_token_name = true;
      let mutable_token_properties = false;
      let mutable_token_uri = true;
  
      // Define burn and freeze permissions for creator
      let tokens_burnable_by_creator = false;
      let tokens_freezable_by_creator = false;
  
      // Define royalty settings (10% royalty)
      let royalty_numerator = 10;
      let royalty_denominator = 100;
    */

    /* Listing using CoinType (Edit to set price)
   public(friend) fun list_with_fixed_price_internal<CoinType>(
        seller: &signer,
        object: object::Object<object::ObjectCore>,
        price: u64,        
    ): object::Object<Listing> acquires SellerListings, Sellers, MarketplaceSigner {
        let constructor_ref = object::create_object(signer::address_of(seller));

        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        object::disable_ungated_transfer(&transfer_ref);

        let listing_signer = object::generate_signer(&constructor_ref);

        let listing = Listing {
            object,
            seller: signer::address_of(seller),
            delete_ref: object::generate_delete_ref(&constructor_ref),
            extend_ref: object::generate_extend_ref(&constructor_ref),
        };
        let fixed_price_listing = FixedPriceListing<CoinType> {
            price,
        };
        move_to(&listing_signer, listing);
        move_to(&listing_signer, fixed_price_listing);

        object::transfer(seller, object, signer::address_of(&listing_signer));

        let listing = object::object_from_constructor_ref(&constructor_ref);

        if (exists<SellerListings>(signer::address_of(seller))) {
            let seller_listings = borrow_global_mut<SellerListings>(signer::address_of(seller));
            smart_vector::push_back(&mut seller_listings.listings, object::object_address(&listing));
        } else {
            let seller_listings = SellerListings {
                listings: smart_vector::new(),
            };
            smart_vector::push_back(&mut seller_listings.listings, object::object_address(&listing));
            move_to(seller, seller_listings);
        };
        if (exists<Sellers>(get_marketplace_signer_addr())) {
            let sellers = borrow_global_mut<Sellers>(get_marketplace_signer_addr());
            if (!smart_vector::contains(&sellers.addresses, &signer::address_of(seller))) {
                smart_vector::push_back(&mut sellers.addresses, signer::address_of(seller));
            }
        } else {
            let sellers = Sellers {
                addresses: smart_vector::new(),
            };
            smart_vector::push_back(&mut sellers.addresses, signer::address_of(seller));
            move_to(&get_marketplace_signer(get_marketplace_signer_addr()), sellers);
        };

        listing
    }
    */

    


}