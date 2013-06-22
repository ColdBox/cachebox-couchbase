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

	// This flag will be added to the beginning of any complex value that was serialized 
	// so the provider knows to deserialize it.  There is overhead in serialization, so we
	// will be avoiding it where possible with any simple values that are stored.
	this.CONVERTED_FLAG = '___CONVERTED___';

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
			URIClass 			= createObject("java", "java.net.URI"),
			// Java URI class
			TimeUnitClass 		= createObject("java", "java.util.concurrent.TimeUnit"),
			// For serialization of complex values
			converter			= createObject("component","coldbox.system.core.conversion.ObjectMarshaller").init(),
			// JavaLoader will be used to load the Jars.  Wait to init until the configure() method
			JavaLoader			= CreateObject("component","coldbox.system.core.javaloader.JavaLoader")
		};
		
		// Provider Property Defaults
		instance.DEFAULTS = {
			objectDefaultTimeout = 30,
            opQueueMaxBlockTime = 5000,
	        opTimeout = 5000,
	        timeoutExceptionThreshold = 5000,
	        ignoreCouchBaseTimeouts = true,
			bucket = "default",
			servers = "localhost:8091", // This can be an array
			username = "",
			password = "",
			jarPath = GetDirectoryFromPath(GetCurrentTemplatePath()) & "jars/"
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
				
		// Massage server URLs to be "PROTOCOL://host:port/pools/"
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
		var config 	= '';
		var props	= [];
		var URIs 	= [];
    	var i = 0;
    	var CouchBaseClientClass = '';
    	var CouchbaseConnectionFactoryBuilder = '';
    	var CouchbaseConnectionFactory = '';
			
		// Validate the configuration
		validateConfiguration();
		config = getConfiguration();
		
		// Prepare the logger
		instance.logger = getCacheFactory().getLogBox().getLogger( this );
		instance.logger.debug("Starting up Couchbaseprovider Cache: #getName()# with configuration: #config.toString()#");
			
		lock name="Couchbaseprovider.config.#instance.cacheID#" type="exclusive" throwontimeout="true" timeout="20"{
		
			try{
			
				// Load up the jars from their path
				instance.JavaLoader.init([
					'#config.jarPath#commons-codec-1.5.jar',
					'#config.jarPath#couchbase-client-1.1.6.jar',
					'#config.jarPath#httpcore-4.1.1.jar',
					'#config.jarPath#httpcore-nio-4.1.1.jar',
					'#config.jarPath#jettison-1.1.jar',
					'#config.jarPath#netty-3.5.5.Final.jar',
					'#config.jarPath#spymemcached-2.8.12.jar'
				]);
			}
			catch(any e) {
				e.printStackTrace();
				throw(message='Error Loading CouchBase Client Jars', detail=e.message & " " & e.detail)
			}		
			
			try{
			
				// Prepare list of servers
				while(++i <= arrayLen(config.servers)) {
					arrayAppend(URIs,instance.URIClass.create(config.servers[i]));					
				}
				
				// Create a connection factory builder
				CouchbaseConnectionFactoryBuilder = instance.JavaLoader.create("com.couchbase.client.CouchbaseConnectionFactoryBuilder").init();
				
				// Set out timeoutes into the factory builder
		        CouchbaseConnectionFactoryBuilder.setOpQueueMaxBlockTime(config.opQueueMaxBlockTime);
		        CouchbaseConnectionFactoryBuilder.setOpTimeout(config.opTimeout);
		        CouchbaseConnectionFactoryBuilder.setTimeoutExceptionThreshold(config.timeoutExceptionThreshold);        
		        
		        // Build our connection factory with the defaults we set above
				CouchbaseConnectionFactory = CouchbaseConnectionFactoryBuilder.buildCouchbaseConnection(URIs, config.bucket, config.password);
		        				
		        // Create actual client class.  
				CouchBaseClientClass = instance.JavaLoader.create("com.couchbase.client.CouchbaseClient");
			}
			catch(any e) {
				e.printStackTrace();
				throw(message='There was an error creating the CouchbaseClient library', detail=e.message & " " & e.detail)
			}
			
			try{
				// Instantiate the client with out connection factory.  This is in a separate try catch to help differentiate between
				// Java classpath issues versus CouchBase connection issues.  
				setCouchBaseClient(CouchBaseClientClass.init(CouchbaseConnectionFactory));
			}
			catch(any e) {
				e.printStackTrace();
				throw(message='There was an error connecting to the Couchbase server. Config: #serializeJSON(config)#', detail=e.message & " " & e.detail)
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
    	getCouchBaseClient().shutDown(5,instance.TimeUnitClass.SECONDS);
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
		return createObject("component", "CouchbaseStats").init( this );		
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
			var md 		= {};
			var keys 	= getKeys();
			var item	= "";
			
			for(item in keys){
				md[item] = getCachedObjectMetadata(item);
			}
			
			return md;
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
    	
    	// Find a way to automatically create this docName and view
    	local.allView = getCouchBaseClient().getView('test','all');
    	local.query = instance.JavaLoader.create("com.couchbase.client.protocol.views.Query").init(); 
    	local.response = getCouchBaseClient().query(local.allView,local.query);
    	    	
    	// Should probably check these each time
    	//local.response.getErrors()
    	
    	local.iterator = local.response.iterator();
    	local.results = [];
    	
    	while(local.iterator.hasNext()) {
    		arrayAppend(local.results,local.iterator.next().getID());
    	}
    	
    	return local.results;
	}
	
	/**
    * get an object's cached metadata
    */
    any function getCachedObjectMetadata(required any objectKey) output="false" {
    	return {
				timespan = 0, hitcount = 1, idleTime = 2,
				 createdtime = 3, lasthit = 4 
			};
	}
	
	/**
    * get an item from cache
    */
    any function get(required any objectKey) output="false" {
    	try {
    		// local.object will always come back as a string
			local.object = getCouchBaseClient().get(arguments.objectKey);
			
			// item is no longer in cache
			if(!structKeyExists(local,"object")) {
				return;
			}
			
			local.convertedFlagLength = len(this.CONVERTED_FLAG);
			// If the stored value had been converted
			if(len(local.object) > local.convertedFlagLength && left(local.object,local.convertedFlagLength) == this.CONVERTED_FLAG) {
				// Strip out the converted flag and deserialize.
				local.object = mid(local.object,local.convertedFlagLength+1,len(local.object)-local.convertedFlagLength);
				return instance.converter.deserializeObject(binaryObject=local.object);
			}
			
			// If was a simple value
			return local.object;
		}
		catch(any e) {
			
			if( isTimeoutException(e) && getConfiguration().ignoreCouchBaseTimeouts) {
				// Return nothing as though it wasn't even found in the cache
				return;
			}
			
			// For any other type of exception, rethrow.
			rethrow;
		}
	}
	
    private boolean function isTimeoutException(required any exception) {
    	return (exception.type == 'net.spy.memcached.OperationTimeoutException' || exception.message == 'Exception waiting for value' || exception.message == 'Interrupted waiting for value');
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
					 any timeout=instance.configuration.objectDefaultTimeout,
					 any lastAccessTimeout="0", // Not used for this provider
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
						  any timeout=instance.configuration.objectDefaultTimeout,
						  any lastAccessTimeout="0", // Not used for this provider
						  any extra) output="false" {

		if(!isSimpleValue(arguments.object)) {
			arguments.object = this.CONVERTED_FLAG & instance.converter.serializeObject( arguments.object );
		}

    	try {
    		
			// You can pass in a net.spy.memcached.transcoders.Transcoder to override the default
			if(structKeyExists(arguments,'extra') && structKeyExists(arguments.extra,'transcoder')) {
				 getCouchBaseClient().set(javaCast("string",arguments.objectKey), javaCast("int",arguments.timeout*60), arguments.object,extra.transcoder);
			} else {
				getCouchBaseClient().set(javaCast("string",arguments.objectKey), javaCast("int",arguments.timeout*60), arguments.object);
			}
		
		}
		catch(any e) {
			
			if( isTimeoutException(e) && getConfiguration().ignoreCouchBaseTimeouts) {
				return false;
			}
			
			// For any other type of exception, rethrow.
			rethrow;
		}
	}	
		
	/**
    * get cache size
    */
    any function getSize() output="false" {
		return getStats().getObjectCount();
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
		
		getCouchBaseClient().flush();		
				 
		var iData = {
			cache	= this
		};
		
		// notify listeners		
		getEventManager().processState("afterCacheClearAll",iData);
		
	}
	
	/**
    * clear an element from cache
    */
    any function clear(required any objectKey) output="false" {
		
		getCouchBaseClient().delete(arguments.objectKey);
		
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
		
	/**
    * set the CouchBase Client
    */
    void function setCouchBaseClient(required any CouchBaseClient) {
		instance.CouchBaseClient = arguments.CouchBaseClient;
	}
		
	/**
    * get the CouchBase Client
    */
    any function getCouchBaseClient() {
		return instance.CouchBaseClient;
	}

}