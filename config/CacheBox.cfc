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
	                provider = "coldbox.system.cache.providers.CacheBoxColdBoxProvider",
	                properties = {
	                    objectDefaultTimeout = 120,
	                    objectDefaultLastAccessTimeout = 30,
	                    useLastAccessTimeouts = true,
	                    reapFrequency = 2,
	                    freeMemoryPercentageThreshold = 0,
	                    evictionPolicy = "LRU",
	                    evictCount = 2,
	                    maxObjects = 300,
	                    objectStore = "ConcurrentSoftReferenceStore" //memory sensitive
	                }
	            },
			   couchBase = {
			        provider="models.providers.CouchBase.CouchBaseColdBoxProvider",
			        properties = {
	                    objectDefaultTimeout = 15,
	                    opQueueMaxBlockTime = 5000,
				        opTimeout = 5000,
				        timeoutExceptionThreshold = 5000,
				        ignoreCouchBaseTimeouts = true,				
			        	bucket="test",
			        	password="pa$$",
			        	servers="127.0.0.1:8091",
			        	jarPath=GetDirectoryFromPath(GetCurrentTemplatePath()) & "../models/providers/CouchBase/jars/"
			        }
				}
			},
	        // Register all event listeners here, they are created in the specified order
	        listeners = []      
	    };
	}   

}