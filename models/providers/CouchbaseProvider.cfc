/**
********************************************************************************
Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldbox.org | www.luismajano.com | www.ortussolutions.com
********************************************************************************
Author: Brad Wood
Description:
	
This CacheBox provider communicates with a single Couchbase node or a 
cluster of Couchbase nodes for a distributed and highly scalable cache store.

*/
component serializable="false" implements="coldbox.system.cache.ICacheProvider"{

	/**
    * Constructor
    */
	CouchbaseProvider function init() {
		// prepare instance data
		instance = {
			// provider name
			name 				= "",
			// Java SDK for Couchbase
			CouchBaseClient 	= "",
			// provider enable flag
			enabled 			= false,
			// reporting enabled flag
			reportingEnabled 	= false,
			// configuration structure
			configuration 		= {},
			// cacheFactory composition
			cacheFactory 		= "",
			// event manager composition
			eventManager		= "",
			// storage composition, even if it does not exist, depends on cache
			store				= "",
			// the cache identifier for this provider
			cacheID				= createObject('java','java.lang.System').identityHashCode(this),
			// Element Cleaner Helper
			elementCleaner		= CreateObject("component","coldbox.system.cache.util.ElementCleaner").init(this),
			// Utilities
			utility				= createObject("component","coldbox.system.core.util.Util"),
			// our UUID creation helper
			uuidHelper			= createobject("java", "java.util.UUID"),
			// Java URI class
			URIClass = createObject("java", "java.net.URI"),
			// Java URI class
			TimeUnitClass = createObject("java", "java.util.concurrent.TimeUnit")			
		};
		
		// Provider Property Defaults
		instance.DEFAULTS = {
			bucket = "default",
			servers = "localhost:8091", // This can be an array
			username = "",
			password = ""
		};		
		
		return this;
	}
	
	/**
    * get the cache name
    */    
	any function getName() output="false" {
		return instance.name;
	}
	
	/**
    * set the cache name
    */    
	void function setName(required name) output="false" {
		instance.name = arguments.name;
	}
	
	/**
    * set the event manager
    */
    void function setEventManager(required any EventManager) output="false" {
    	instance.eventManager = arguments.eventManager;
    }
	
    /**
    * get the event manager
    */
    any function getEventManager() output="false" {
    	return instance.eventManager;
    }
    
	/**
    * get the cache configuration structure
    */
    any function getConfiguration() output="false" {
		return instance.configuration;
	}
	
	/**
    * set the cache configuration structure
    */
    void function setConfiguration(required any configuration) output="false" {
		instance.configuration = arguments.configuration;
	}
	
	/**
    * get the associated cache factory
    */
    any function getCacheFactory() output="false" {
		return instance.cacheFactory;
	}
	
	/**
	* Validate the incoming configuration and make necessary defaults
	**/
	private void function validateConfiguration() output="false"{
		var cacheConfig = getConfiguration();
		var key			= "";
		
		// Validate configuration values, if they don't exist, then default them to DEFAULTS
		for(key in instance.DEFAULTS){
			if( NOT structKeyExists(cacheConfig, key) OR (isSimpleValue(cacheConfig[key]) AND NOT len(cacheConfig[key])) ){
				cacheConfig[key] = instance.DEFAULTS[key];
			}
			
			// Force servers to be an array even if there's only one and ensure proper URI format
			if(key == 'servers') {
				cacheConfig[key] = formatServers(cacheConfig[key]);
			}
			
		}
	}
	
	/**
    * configure the cache for operation
    */
    private array function formatServers(servers) {
    	var i = 0;
    	
		if(!isArray(servers)) {
			servers = listToArray(servers);
		}
				
		// Massage server URLs to be PROTOCOL://host:port/pools/
		while(++i <= arrayLen(servers)) {
			
			// Add protocol if neccessar
			if(!findNoCase("http",servers[i])) {
				servers[i] = "http://" & servers[i];
			}
			
			// Strip trailing slash
			if(right(servers[i],1) == '/') {
				servers[i] = mid(servers[i],1,len(servers[i])-1);
			}
			
			// Add directory
			if(right(servers[i],6) != '/pools') {
				servers[i] &= '/pools';
			}
			
		} // Server loop
		
		return servers;
	}
	
	/**
    * configure the cache for operation
    */
    void function configure() output="false" {
		var config 	= getConfiguration();
		var props	= [];
		var URIs 	= [];
    	var i = 0;
    	var CouchBaseClientClass = '';
				
		lock name="Couchbaseprovider.config.#instance.cacheID#" type="exclusive" throwontimeout="true" timeout="20"{
		
			// Prepare the logger
			instance.logger = getCacheFactory().getLogBox().getLogger( this );
			instance.logger.debug("Starting up Couchbaseprovider Cache: #getName()# with configuration: #config.toString()#");
			
			// Validate the configuration
			validateConfiguration();
			var cacheConfig = getConfiguration();
			
			while(++i <= arrayLen(config.servers)) {
				arrayAppend(URIs,instance.URIClass.create(config.servers[i]));					
			}
			
			try{
				CouchBaseClientClass = createObject("java","com.couchbase.client.CouchbaseClient");
			}
			catch(any e) {
				e.printStackTrace();
				throw(message='There was an error creating the CouchbaseClient library', detail=e.message)
			}	
			try{
				instance.CouchBaseClient = CouchBaseClientClass.init(URIs, config.bucket, config.password);
			}
			catch(any e) {
				e.printStackTrace();
				throw(message='There was an error connecting to the Couchbase server. Config: #serializeJSON(config)#', detail=e.message)
			}
			
			// enabled cache
			instance.enabled = true;
			instance.reportingEnabled = true;
			instance.logger.info("Cache #getName()# started up successfully");
		}
		
	}
	
	/**
    * shutdown the cache
    */
    void function shutdown() output="false" {
    	instance.CouchBaseClient.shutDown(5,instance.TimeUnitClass.SECONDS);
		instance.logger.info("CouchbaseProvider Cache: #getName()# has been shutdown.");
	}
	
	/*
	* Indicates if cache is ready for operation
	*/
	any function isEnabled() output="false" {
		return instance.enabled;
	} 

	/*
	* Indicates if cache is ready for reporting
	*/
	any function isReportingEnabled() output="false" {
		return instance.reportingEnabled;
	}
	
	/*
	* Get the cache statistics object as coldbox.system.cache.util.ICacheStats
	* @colddoc:generic coldbox.system.cache.util.ICacheStats
	*/
	any function getStats() output="false" {
		//return createObject("component", "coldbox.system.cache.providers.Couchbase-lib.CouchbaseStats").init( this );		
	}
	
	/**
    * clear the cache stats: 
    */
    void function clearStatistics() output="false" {
	}
	
	/**
    * Returns the underlying cache engine: Not enabled in this provider
    */
    any function getObjectStore() output="false" {
    	// This provider uses an external object store
	}
	
	/**
    * get the cache's metadata report
    */
    any function getStoreMetadataReport() output="false" { 
    	return structNew();
    	
    	/* NOT IMPLEMENTED YET
	    	
			var md 		= {};
			var keys 	= getKeys();
			var item	= "";
			
			for(item in keys){
				md[item] = getCachedObjectMetadata(item);
			}
			
			return md;
			
		*/
	}
	
	/**
	* Get a key lookup structure where cachebox can build the report on. Ex: [timeout=timeout,lastAccessTimeout=idleTimeout].  It is a way for the visualizer to construct the columns correctly on the reports
	*/
	any function getStoreMetadataKeyMap() output="false"{
		var keyMap = {
				timeout = "timespan", hits = "hitcount", lastAccessTimeout = "idleTime",
				created = "createdtime", LastAccessed = "lasthit"
			};
		return keymap;
	}
	
	/**
    * get all the keys in this provider
    */
    any function getKeys() output="false" {
    	// Figure this out using TAP
		return [];
	}
	
	/**
    * get an object's cached metadata
    */
    any function getCachedObjectMetadata(required any objectKey) output="false" {
    	return structNew();
    	
    	/* NOT IMPLEMENTED YET
    	
			return cacheGetMetadata( arguments.objectKey, getConfiguration().cacheName );
		*/
	}
	
	/**
    * get an item from cache
    */
    any function get(required any objectKey) output="false" {
		return instance.CouchBaseClient.get(arguments.objectKey);
	}
	
	/**
    * get an item silently from cache, no stats advised: Stats not available on Couchbase
    */
    any function getQuiet(required any objectKey) output="false" {
		// not implemented by Couchbase yet
		return get(argumentCollection=arguments);
	}
	
	/**
    * Not implemented by this cache
    */
    any function isExpired(required any objectKey) output="false" {
		return false;
	}
	 
	/**
    * check if object in cache
    */
    any function lookup(required any objectKey) output="false" {
    	local.tmp = get(objectKey);
    	return structKeyExists(local,'tmp');
	}
	
	/**
    * check if object in cache with no stats: Stats not available on Couchbase
    */
    any function lookupQuiet(required any objectKey) output="false" {
		// not possible yet on Couchbase
		return lookup(arguments.objectKey);
	}
	
	/**
    * set an object in cache
    */
    any function set(required any objectKey,
					 required any object,
					 any timeout="0",
					 any lastAccessTimeout="0",
					 any extra) output="false" {
		
		setQuiet(argumentCollection=arguments);
		
		//ColdBox events
		var iData = { 
			cache				= this,
			cacheObject			= arguments.object,
			cacheObjectKey 		= arguments.objectKey,
			cacheObjectTimeout 	= arguments.timeout,
			cacheObjectLastAccessTimeout = arguments.lastAccessTimeout
		};		
		getEventManager().processState("afterCacheElementInsert",iData);
		
		return true;
	}	
	
	/**
    * set an object in cache with no advising to events
    */
    any function setQuiet(required any objectKey,
						  required any object,
						  any timeout="0",
						  any lastAccessTimeout="0",
						  any extra) output="false" {

		// You can pass in a net.spy.memcached.transcoders.Transcoder to override the default
		if(structKeyExists(arguments,'extra') && structKeyExists(arguments.extra,'transcoder')) {
			 instance.CouchBaseClient.set(arguments.objectKey, arguments.timeout*60, arguments.object,extra.transcoder);
		} else {
			instance.CouchBaseClient.set(arguments.objectKey, arguments.timeout*60, arguments.object);
		}
		
		return true;
	}	
		
	/**
    * get cache size
    */
    any function getSize() output="false" {
    	// NOT IMPLEMENTED YET
		return 0;
	}
	
	/**
    * Not implemented by this cache
    */
    void function reap() output="false" {
		// Not implemented by this provider
	}
	
	/**
    * clear all elements from cache
    */
    void function clearAll() output="false" {
		/*
		Couchbase doesn't allow for this
		I'm not broadcasting the interception point since I didn't
		actually clear anything
		 
		var iData = {
			cache	= this
		};
		
		// notify listeners		
		getEventManager().processState("afterCacheClearAll",iData);
		*/
	}
	
	/**
    * clear an element from cache
    */
    any function clear(required any objectKey) output="false" {
		
		instance.CouchbaseClient.delete(arguments.objectKey);
		
		//ColdBox events
		var iData = { 
			cache				= this,
			cacheObjectKey 		= arguments.objectKey
		};		
		getEventManager().processState("afterCacheElementRemoved",iData);
		
		return true;
	}
	
	/**
    * clear with no advising to events
    */
    any function clearQuiet(required any objectKey) output="false" {
		// normal clear, not implemented by Couchbase
		clear(arguments.objectKey);
		return true;
	}
	
	/**
	* Clear by key snippet
	*/
	void function clearByKeySnippet(required keySnippet, regex=false, async=false) output="false" {
		/*
		Not possible in Couchbase
		
		var threadName = "clearByKeySnippet_#replace(instance.uuidHelper.randomUUID(),"-","","all")#";
		
		// Async? IF so, do checks
		if( arguments.async AND NOT instance.utility.inThread() ){
			thread name="#threadName#"{
				instance.elementCleaner.clearByKeySnippet(arguments.keySnippet,arguments.regex);
			}
		}
		else{
			instance.elementCleaner.clearByKeySnippet(arguments.keySnippet,arguments.regex);
		}
		*/
	}
	
	/**
    * not implemented by cache
    */
    void function expireAll() output="false" { 
		// Not implemented by this cache
	}
	
	/**
    * not implemented by cache
    */
    void function expireObject(required any objectKey) output="false" {
		//not implemented
	}
		
	/**
    * set the associated cache factory
    */
    void function setCacheFactory(required any cacheFactory) output="false" {
		instance.cacheFactory = arguments.cacheFactory;
	}

}