/********************************************************************************
Copyright 2005-2007 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldbox.org | www.luismajano.com | www.ortussolutions.com
********************************************************************************

Author     :	Luis Majano
Date        :	9/3/2007
Description :
	Request service Test
**/
component extends="CouchbaseProviderTest"{
	
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
		// Find a way to make the "couchbaseApp" mapping dynamic for people (like Brad) running this in the root :)
		cache = getMockBox().createMock("couchbaseApp.model.providers.Couchbase.CouchbaseColdboxProvider").init();
		// Decorate it
		cache.setConfiguration( config );
		cache.setCacheFactory( mockFactory );
		cache.setEventManager( mockEventManager );
		
		// Configure the provider
		cache.configure();
	}
	
	function testGetPrefixes(){
		assertTrue( len( cache.getViewCacheKeyPrefix() ) );
		assertTrue( len( cache.getEventCacheKeyPrefix() ) );
	}
	
	function testColdBox(){
		mockColdbox = getMockBox().createStub().$("mock",true);
		cache.setColdBox( mockColdBox );
		assertTrue( cache.getColdBox().mock() );
	}
	
	function testURLFacade(){
		assertTrue( isObject( cache.getEventURLFacade() ) );
	}
	
	function testClearAllEvents(){
		cache.clearAllEvents();
	}
	
	function testclearAllViews(){
		cache.clearAllViews();
	}
	
	function testClearEvent(){
		cache.clearEvent("main");
	}
	
	function testClearEventMulti(){
		cache.clearEvent("main");
	}
	
	function testClearView(){
		cache.clearView("viewTest");
	}
	
	function testclearViewMulti(){
		cache.clearViewMulti("viewTest");
	}
	
}