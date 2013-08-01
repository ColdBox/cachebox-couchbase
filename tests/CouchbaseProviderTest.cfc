/********************************************************************************
Copyright 2005-2007 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldbox.org | www.luismajano.com | www.ortussolutions.com
********************************************************************************

Author     :	Luis Majano
Date        :	9/3/2007
Description :
	Request service Test
**/
component extends="coldbox.system.testing.BaseTestCase"{
	
	this.loadColdBox = false;

	function setup(){
		super.setup();
		
		//Mocks
		mockFactory  = getMockBox().createEmptyMock(className='coldbox.system.cache.CacheFactory');
		mockEventManager  = getMockBox().createEmptyMock(className='coldbox.system.core.events.EventPoolManager');
		mockLogBox	 = getMockBox().createEmptyMock("coldbox.system.logging.LogBox");
		mockLogger	 = getMockBox().createEmptyMock("coldbox.system.logging.Logger");	
		// Mock Methods
		mockFactory.$("getLogBox",mockLogBox);
		mockLogBox.$("getLogger", mockLogger);
		mockLogger.$("error").$("debug").$("info").$("canDebug",true).$("canInfo",true).$("canError",true);
		mockEventManager.$("processState");
		
		config = {
            objectDefaultTimeout = 15,
            opQueueMaxBlockTime = 5000,
	        opTimeout = 5000,
	        timeoutExceptionThreshold = 5000,
	        ignoreCouchBaseTimeouts = true,				
        	bucket="default",
        	password="",
        	servers="127.0.0.1:8091",
        	// This switches the internal provider from normal cacheBox to coldbox enabled cachebox
			coldboxEnabled = false
        };
		
		// Create Provider
		cache = getMockBox().createMock("couchbaseApp.model.providers.Couchbase.CouchbaseProvider").init();
		// Decorate it
		cache.setConfiguration( config );
		cache.setCacheFactory( mockFactory );
		cache.setEventManager( mockEventManager );
		
		// Configure the provider
		cache.configure();
	}
	
	function testShutdown(){
		//cache.shutdown();
	}
	
	function testLookup(){
		// null test
		cache.$("get");
		assertFalse( cache.lookup( 'invalid' ) );
		
		// something
		cache.$("get", this);
		assertTrue( cache.lookup( 'valid' ) );	
	}
	
	function testLookupQuiet(){
		// null test
		cache.$("get");
		assertFalse( cache.lookupQuiet( 'invalid' ) );
		
		// something
		cache.$("get", this);
		assertTrue( cache.lookupQuiet( 'valid' ) );	
	}
	
	function testGet(){
		// null value
		r = cache.get( 'invalid' );
		assertTrue( isNull( r ) );
			
		testVal = {name="luis", age=32};
		cache.getObjectStore().set( "unitTestKey", 500, testVal );
		
	}
	
	
	
}