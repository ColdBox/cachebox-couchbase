/**
********************************************************************************
Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldbox.org | www.luismajano.com | www.ortussolutions.com
********************************************************************************
Author: Brad Wood, Luis Majano
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
			cacheID				= createObject('java','java.lang.System').identityHashCode( this ),
			// Element Cleaner Helper
			elementCleaner		= CreateObject("component","coldbox.system.cache.util.ElementCleaner").init( this ),
			// Utilities
			utility				= createObject("component","coldbox.system.core.util.Util"),
			// our UUID creation helper
			uuidHelper			= createobject("java", "java.util.UUID"),
			// Java URI class
			URIClass 			= createObject("java", "java.net.URI"),
			// Java Time Units
			TimeUnitClass 		= createObject("java", "java.util.concurrent.TimeUnit"),
			// For serialization of complex values
			converter			= createObject("component","coldbox.system.core.conversion.ObjectMarshaller").init(),
			// Core ColdBox JavaLoader will be used to load the Jars.  Wait to init until the configure() method
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
			jarPath = GetDirectoryFromPath( GetCurrentTemplatePath() ) & "jars/"
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
				
	/**
    * get the JavaLoader
    */
    any function getJavaLoader() {
		return instance.JavaLoader;
	}
	
	/**
	* Validate the incoming configuration and make necessary defaults
	**/
	private void function validateConfiguration() output="false"{
		var cacheConfig = getConfiguration();
		var key			= "";
		
		// Validate configuration values, if they don't exist, then default them to DEFAULTS
		for(key in instance.DEFAULTS){
			if( NOT structKeyExists( cacheConfig, key) OR ( isSimpleValue( cacheConfig[ key ] ) AND NOT len( cacheConfig[ key ] ) ) ){
				cacheConfig[ key ] = instance.DEFAULTS[ key ];
			}
			
			// Force servers to be an array even if there's only one and ensure proper URI format
			if( key == 'servers' ) {
				cacheConfig[ key ] = formatServers( cacheConfig[ key ] );
			}
			
		}
	}
	
	/**
    * Format the incoming simple couchbas server URL location strings into our format
    */
    private array function formatServers(required servers) {
    	var i = 0;
    	
		if( !isArray( servers ) ){
			servers = listToArray( servers );
		}
				
		// Massage server URLs to be "PROTOCOL://host:port/pools/"
		while(++i <= arrayLen( servers ) ){
			
			// Add protocol if neccessary
			if( !findNoCase( "http",servers[ i ] ) ){
				servers[ i ] = "http://" & servers[ i ];
			}
			
			// Strip trailing slash via regex, its fast
			servers[ i ] = reReplace( servers[ i ], "/$", "");
			
			// Add directory
			if( right( servers[ i ], 6 ) != '/pools' ){
				servers[ i ] &= '/pools';
			}
			
		} // end server loop
		
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
    	var couchBaseClientClass = '';
    	var couchbaseConnectionFactoryBuilder = '';
    	var couchbaseConnectionFactory = '';
			
		// lock creation	
		lock name="Couchbaseprovider.config.#instance.cacheID#" type="exclusive" throwontimeout="true" timeout="20"{
		
			// Prepare the logger
			instance.logger = getCacheFactory().getLogBox().getLogger( this );
			instance.logger.debug("Starting up Couchbaseprovider Cache: #getName()# with configuration: #config.toString()#");
			
			// Validate the configuration
			validateConfiguration();
		
			try{
				// Load up the jars from their path
				getJavaLoader().init([
					'#config.jarPath#commons-codec-1.5.jar',
					'#config.jarPath#couchbase-client-1.1.7.jar',
					'#config.jarPath#httpcore-4.1.1.jar',
					'#config.jarPath#httpcore-nio-4.1.1.jar',
					'#config.jarPath#jettison-1.1.jar',
					'#config.jarPath#netty-3.5.5.Final.jar',
					'#config.jarPath#spymemcached-2.9.0.jar'
				]);
			}
			catch(any e) {
				e.printStackTrace();
				instance.logger.error("Error Loading Couchbase Client Jars: #e.message# #e.detail#", e );
				throw(message='Error Loading CouchBase Client Jars', detail=e.message & " " & e.detail);
			}		
			
			try{
			
				// Prepare list of servers
				while(++i <= arrayLen( config.servers ) ){
					arrayAppend( URIs, instance.URIClass.create( config.servers[ i ] ) );					
				}
				
				// Create a connection factory builder
				CouchbaseConnectionFactoryBuilder = getJavaLoader().create("com.couchbase.client.CouchbaseConnectionFactoryBuilder").init();
				
				// Set out timeouts into the factory builder
		        CouchbaseConnectionFactoryBuilder.setOpQueueMaxBlockTime( config.opQueueMaxBlockTime );
		        CouchbaseConnectionFactoryBuilder.setOpTimeout( config.opTimeout );
		        CouchbaseConnectionFactoryBuilder.setTimeoutExceptionThreshold( config.timeoutExceptionThreshold );        
		        
		        // Build our connection factory with the defaults we set above
				CouchbaseConnectionFactory = CouchbaseConnectionFactoryBuilder.buildCouchbaseConnection( URIs, config.bucket, config.password );
		        				
		        // Create actual client class.  
				CouchBaseClientClass = getJavaLoader().create("com.couchbase.client.CouchbaseClient");
			}
			catch(any e) {
				e.printStackTrace();
				instance.logger.error("There was an error creating the CouchbaseClient library: #e.message# #e.detail#", e );
				throw(message='There was an error creating the CouchbaseClient library', detail=e.message & " " & e.detail);
			}
			
			try{
				// Instantiate the client with out connection factory.  This is in a separate try catch to help differentiate between
				// Java classpath issues versus CouchBase connection issues.  
				setCouchBaseClient( CouchBaseClientClass.init( CouchbaseConnectionFactory ) );
			}
			catch(any e) {
				e.printStackTrace();
				instance.logger.error("There was an error connecting to the Couchbase server. Config: #serializeJSON(config)#: #e.message# #e.detail#", e );
				throw(message='There was an error connecting to the Couchbase server. Config: #serializeJSON(config)#', detail=e.message & " " & e.detail);
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
    	getCouchBaseClient().shutDown( 5, instance.TimeUnitClass.SECONDS );
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
		return new CouchbaseStats( this );		
	}
	
	/**
    * clear the cache stats: 
    */
    void function clearStatistics() output="false" {
    	// Not implemented
	}
	
	/**
    * Returns the underlying cache engine represented by a Couchbaseclient object
    * http://www.couchbase.com/autodocs/couchbase-java-client-1.1.5/index.html
    */
    any function getObjectStore() output="false" {
    	// This provider uses an external object store
    	return getCouchbaseClient();
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
				LastAccessed = "LastAccessed",
				isExpired = "isExpired",
				timeout = "timeout",
				lastAccessTimeout = "NOT_SUPPORTED",
				hits = "NOT_SUPPORTED",
				created = "NOT_SUPPORTED"
			};
		return keymap;
	}
	
	/**
    * get all the keys in this provider
    */
    any function getKeys() output="false" {
    	
    	ensureViewExists("allKeys");
    	
		// The only reason I'm try/catching this is that the Java exception has an object for the 'type
		// which makes ColdBox's error handing blow up since it tries to use the type as a string.
    	try{
	    	local.allView = getCouchBaseClient().getView('CacheBox_allKeys','allKeys');
	    	local.query = getJavaLoader().create("com.couchbase.client.protocol.views.Query").init();
	    	local.StaleClass = getJavaLoader().create("com.couchbase.client.protocol.views.Stale");
	    	// Just return the keys, not the docs
	    	local.query.setIncludeDocs(false);
	    	// request fresh data
	    	local.query.setStale(local.StaleClass.FALSE);
	    	local.response = getCouchBaseClient().query(local.allView,local.query);
		}
		catch(any e) {
			// Rethrow the error
			throw(message=e.message, detail=e.detail, type="couchbase.view.exception");
		}
		
    	// Were there errors
    	if(arrayLen(local.response.getErrors())){
    		// This will log only and not throw an exception
    		// PLEASE NOTE, the response received may not include all documents if one or more nodes are offline 
	    	// and not yet failed over.  CouchBase basically sends back what docs it _can_ access and ignores the other nodes.
    		handleRowErrors('There was an error executing the view allKeys',local.response.getErrors());
    	}
    	
    	local.iterator = local.response.iterator();
    	local.results = [];
    	
    	while(local.iterator.hasNext()) {
    		arrayAppend(local.results,local.iterator.next().getId());
    	}
    	
    	return local.results;
	}
	
	/**
    * Deal with errors that came back from the cluster
    * rowErrors is an array of com.couchbase.client.protocol.views.RowError
    */
    void function handleRowErrors(message, rowErrors) {
    	local.detail = '';
    	for(local.error in arguments.rowErrors) {
    		local.detail &= local.error.getFrom();
    		local.detail &= local.error.getReason();
    	}
    	
    	// It appears that there is still a useful result even if errors were returned so
    	// we'll just log it and not interrupt the request by throwing.  
    	instance.logger.warn(arguments.message, local.detail);
    	//Throw(message=arguments.message, detail=local.detail);
    }
    
	/**
    * Ensure that a view exists on the cluster
    * http://tugdualgrall.blogspot.com/2012/12/couchbase-101-create-views-mapreduce.html
    */
    void function ensureViewExists(viewName) {
    	
    	local.designDocumentName = 'CacheBox_' & arguments.viewName;
    	
    	// CouchBase doesn't provide a way to check for DesignDocuments, so try to retrieve it and catch the error.
    	// This should only error the first time and will run successfully every time after.
    	try {
    		getCouchBaseClient().getDesignDocument(local.designDocumentName);	
    	}
    	catch('com.couchbase.client.protocol.views.InvalidViewException' e) {
    		
    		// Create it    		
			local.designDocument = getJavaLoader().create("com.couchbase.client.protocol.views.DesignDocument").init(local.designDocumentName);

			// If we start using other views, this function will need to be dynamic based on the view.
			local.mapFunction = '
			function (doc, meta) {
			  emit(meta.id, null);
			}';
			
			// If using reduce function, pass it as third parameter.
			local.viewDesign = getJavaLoader().create("com.couchbase.client.protocol.views.ViewDesign").init(arguments.viewName,local.mapFunction);
			local.designDocument.getViews().add(local.viewDesign);
			getCouchBaseClient().createDesignDoc(local.designDocument);
    		
    		// View creation and population is asynchronous so we'll wait a while until it's ready
			local.attempts = 0;
			while(++attempts <= 5) {
				try {
					// Access the view
			    	local.allView = getClient().getView(local.designDocumentName,arguments.viewName);
			    	local.query = getJavaLoader().create("com.couchbase.client.protocol.views.Query").init();
			    	local.StaleClass = getJavaLoader().create("com.couchbase.client.protocol.views.Stale");
			    	local.query.setIncludeDocs(false);
			    	// This will force a re-index
			    	local.query.setStale(local.StaleClass.FALSE);
			    	getClient().query(local.allView,local.query);
				}
				catch(Any e) {
					// Wait a bit before trying again
					sleep(1000);
				}
			}
    		
    		// We either successfully executed our new view, or we gave up trying.
    		return;
    	}
    	
    }
	
	/**
    * get an object's cached metadata
    */
    any function getCachedObjectMetadata(required any objectKey) output="false" {
    	
    	local.keyStats = {
				timeout = "",
				LastAccessed = "",
				timeExpires = "",
				isExpired = 0,
				NOT_SUPPORTED = ""
			};
    	
    	// Get stats for this key
    	local.stats = getCouchBaseClient().getKeyStats(objectKey).get();
    	if(structKeyExists(local,"stats")) {
    		
    		local.key_exptime =  iif(structKeyExists(local.stats,"key_exptime"), "local.stats['key_exptime']",  0);
    		
    		// These are opoch times.  Seconds since 1/1/1970 UTC
    		if(val(local.key_exptime)) {
    			// last access and expire time is epoch seconds added to 1/1/1970 and converted to local time  
    			local.keyStats.timeExpires = DateAdd("s", local.key_exptime ,DateConvert("utc2Local", "January 1 1970 00:00"));
    		}
			
    	}
    	
    	return local.keyStats;
	}
	
	/**
    * get an item from cache
    */
    any function get(required any objectKey) output="false" {
    	try {
    		// local.object will always come back as a string
    		local.object = getCouchBaseClient().get( javacast( "string", arguments.objectKey ) );
			
			// item is no longer in cache, return null
			if( !structKeyExists( local, "object" ) ){
				return;
			}
			
			local.convertedFlagLength = len( this.CONVERTED_FLAG );
			// If the stored value had been converted
			if( len( local.object ) > local.convertedFlagLength && left( local.object, local.convertedFlagLength ) == this.CONVERTED_FLAG) {
				// Strip out the converted flag and deserialize.
				local.object = mid( local.object, local.convertedFlagLength+1, len( local.object ) - local.convertedFlagLength );
				return instance.converter.deserializeObject(binaryObject=local.object);
			}
			
			// If was a simple value
			return local.object;
		}
		catch(any e) {
			
			if( isTimeoutException( e ) && getConfiguration().ignoreCouchBaseTimeouts ) {
				// log it
				instance.logger.error( "Couchbase timeout exception detected: #e.message# #e.detail#", e );
				// Return nothing as though it wasn't even found in the cache
				return;
			}
			
			// For any other type of exception, rethrow.
			rethrow;
		}
	}
	
	/**
    * get an item silently from cache, no stats advised: Stats not available on Couchbase
    */
    any function getQuiet(required any objectKey) output="false" {
		// "quiet" not implemented by Couchbase yet
		return get(argumentCollection=arguments);
	}
	
	/**
    * Not implemented by this cache
    */
    any function isExpired(required any objectKey) output="false" {
		return getCachedObjectMetadata( arguments.objectKey ).isExpired;
	}
	 
	/**
    * check if object in cache
    */
    any function lookup(required any objectKey) output="false" {
    	return ( isNull( get( objectKey ) ) ? false : true );
	}
	
	/**
    * check if object in cache with no stats: Stats not available on Couchbase
    */
    any function lookupQuiet(required any objectKey) output="false" {
		// not possible yet on Couchbase
		return lookup( arguments.objectKey );
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
		
	}	
	
	/**
    * set an object in cache with no advising to events
    */
    any function setQuiet(required any objectKey,
						  required any object,
						  any timeout=instance.configuration.objectDefaultTimeout,
						  any lastAccessTimeout="0", // Not used for this provider
						  any extra) output="false" {

		// "quiet" "not implemented by Couchbase yet
		
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
				return;
			}
			
			// For any other type of exception, rethrow.
			rethrow;
		}
	}	
		
	/**
    * get cache size
    * @tested
    */
    any function getSize() output="false" {
		return getStats().getObjectCount();
	}
	
	/**
    * Not implemented by this cache
    * @tested
    */
    void function reap() output="false" {
		// Not implemented by this provider
	}
	
	/**
    * clear all elements from cache
    * @tested
    */
    void function clearAll() output="false" {
		
		// If flush is not enabled for this bucket, no error will be thrown.  The call will simply return and nothing will happen.
		// Be very careful calling this.  It is an intensive asynch operation and the cache won't receive any new items until the flush
		// is finished which might take a few minutes.
		getCouchBaseClient().flush();		
				 
		var iData = {
			cache	= this
		};
		
		// notify listeners		
		getEventManager().processState("afterCacheClearAll",iData);
	}
	
	/**
    * clear an element from cache and returns the couchbase java future
    * @tested
    */
    any function clear(required any objectKey) output="false" {
		
		// Delete from couchbase
		var future = getCouchBaseClient().delete( arguments.objectKey );
		
		//ColdBox events
		var iData = { 
			cache				= this,
			cacheObjectKey 		= arguments.objectKey,
			couchbaseFuture		= future
		};		
		getEventManager().processState( "afterCacheElementRemoved", iData );
		
		return future;
	}
	
	/**
    * Clear with no advising to events and returns with the couchbase java future
    * @tested
    */
    any function clearQuiet(required any objectKey) output="false" {
		// normal clear, not implemented by Couchbase
		return clear( arguments.objectKey );
	}
	
	/**
	* Clear by key snippet
	*/
	void function clearByKeySnippet(required keySnippet, regex=false, async=false) output="false" {

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
		
	}
	
	/**
    * Expiration not implemented by couchbase so clears are issued
    * @tested
    */
    void function expireAll() output="false"{ 
		clearAll();
	}
	
	/**
    * Expiration not implemented by couchbase so clear is issued
    * @tested
    */
    void function expireObject(required any objectKey) output="false"{
		clear( arguments.objectKey );
	}

	/************************************** PRIVATE *********************************************/
	
	private boolean function isTimeoutException(required any exception){
    	return (exception.type == 'net.spy.memcached.OperationTimeoutException' || exception.message == 'Exception waiting for value' || exception.message == 'Interrupted waiting for value');
	}

}