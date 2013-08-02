/**
********************************************************************************
Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldbox.org | www.luismajano.com | www.ortussolutions.com
********************************************************************************
Description:

This is a sample CacheBox configuraiton file to integrate with Couchbase

*/
component {

	function configure(){
	    // The CacheBox configuration structure DSL
	    cacheBox = {
	        // LogBox Configuration file
	        logBoxConfig = "coldbox.system.cache.config.LogBox", 
	        
	        // Scope registration, automatically register the cachebox factory instance on any CF scope
	        // By default it registers itself on application scope
	        scopeRegistration = {
	            enabled = true,
	            scope   = "application", // valid CF scope
	            key     = "cacheBox"
	        },
	        
	        // The defaultCache has an implicit name of "default" which is a reserved cache name
	        // It also has a default provider of cachebox which cannot be changed.
	        // All timeouts are in minutes
	        // Please note that each object store could have more configuration properties
	        defaultCache = {
	            objectDefaultTimeout = 60,
	            objectDefaultLastAccessTimeout = 30,
	            useLastAccessTimeouts = true,
	            reapFrequency = 2,
	            freeMemoryPercentageThreshold = 0,
	            evictionPolicy = "LRU",
	            evictCount = 1,
	            maxObjects = 200,
	            // Our default store is the concurrent soft reference
	            objectStore = "ConcurrentSoftReferenceStore",
	            // This switches the internal provider from normal cacheBox to coldbox enabled cachebox
	            coldboxEnabled = false
	        },
	        
	        // Register all the custom named caches you like here
	        caches = { 
		        template = {
	                provider="couchbaseApp.model.providers.Couchbase.CouchbaseColdboxProvider",
			       properties = {
	                    objectDefaultTimeout = 15,
	                    opQueueMaxBlockTime = 5000,
				        opTimeout = 5000,
				        timeoutExceptionThreshold = 5000,
				        ignoreCouchBaseTimeouts = true,				
			        	bucket="default",
			        	password="",
			        	servers="127.0.0.1:8091"
			        }
	            },
			   couchBase = {
			        provider="couchbaseApp.model.providers.Couchbase.CouchbaseProvider",
			        properties = {
	                    objectDefaultTimeout = 15,
	                    opQueueMaxBlockTime = 5000,
				        opTimeout = 5000,
				        timeoutExceptionThreshold = 5000,
				        ignoreCouchBaseTimeouts = true,				
			        	bucket="default",
			        	password="",
			        	servers="127.0.0.1:8091"
			        }
				}
			},
	        // Register all event listeners here, they are created in the specified order
	        listeners = []      
	    };
	}   

}