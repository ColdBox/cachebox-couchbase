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

	/**
    * Constructor
    */
	CouchbaseProvider function init() {
		// prepare instance data
		instance = {
			// provider name
			name 				= "",
			// provider version
			version				= "1.0",
			// Java SDK for Couchbase
			couchbaseClient 	= "",
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
			timeUnitClass 		= createObject("java", "java.util.concurrent.TimeUnit"),
			// For serialization of complex values
			converter			= createObject("component","coldbox.system.core.conversion.ObjectMarshaller").init(),
			// JavaLoader Static ID
			javaLoaderID 		= ""
		};
		
		// JavaLoader set static ID
		instance.javaLoaderID = "couchbase-provider-#instance.version#-laoder";
		
		// Provider Property Defaults
		instance.DEFAULTS = {
			objectDefaultTimeout = 30,
            opQueueMaxBlockTime = 5000,
	        opTimeout = 5000,
	        timeoutExceptionThreshold = 5000,
	        ignoreCouchbaseTimeouts = true,
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
    * get the cache provider version
    */    
	any function getVersion() output="false" {
		return instance.version;
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
    * set the Couchbase Client
    */
    void function setCouchbaseClient(required any CouchbaseClient) {
		instance.CouchbaseClient = arguments.CouchbaseClient;
	}
		
	/**
    * get the Couchbase Client
    */
    any function getCouchbaseClient() {
		return instance.CouchbaseClient;
	}
				
	/**
    * get the JavaLoader
    */
    any function getJavaLoader() {
		return server[ instance.javaLoaderID ];
	}
	
	/**
	* Load JavaLoader
	*/
	private function loadJavaLoader(required paths){
		// verify if not in server scope
		if( ! structKeyExists( server, instance.javaLoaderID ) ){
			lock name="#instance.javaLoaderID#" throwOnTimeout="true" timeout="15" type="exclusive"{
				if( ! structKeyExists( server, instance.javaLoaderID ) ){
					// Create and load
					server[ instance.javaLoaderID ] = new coldbox.system.core.javaloader.JavaLoader( arguments.paths );
				}
			} 
		} // end if static server check
		else{
			lock name="#instance.javaLoaderID#" throwOnTimeout="true" timeout="15" type="readonly"{
				server[ instance.javaLoaderID ].init( arguments.paths );
			}
		}
	}
	
	/**
    * configure the cache for operation
    */
    void function configure() output="false" {
		var config 	= getConfiguration();
		var props	= [];
		var URIs 	= [];
    	var i = 0;
    	var couchbaseClientClass = '';
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
				// Load up javaLoader
				loadJavaLoader( [
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
				throw(message='Error Loading Couchbase Client Jars', detail=e.message & " " & e.detail);
			}		
			
			try{
			
				// Prepare list of servers
				while(++i <= arrayLen( config.servers ) ){
					arrayAppend( URIs, instance.URIClass.create( config.servers[ i ] ) );					
				}
				
				// Create a connection factory builder
				couchbaseConnectionFactoryBuilder = getJavaLoader().create("com.couchbase.client.CouchbaseConnectionFactoryBuilder").init();
				
				// Set out timeouts into the factory builder
		        couchbaseConnectionFactoryBuilder.setOpQueueMaxBlockTime( config.opQueueMaxBlockTime );
		        couchbaseConnectionFactoryBuilder.setOpTimeout( config.opTimeout );
		        couchbaseConnectionFactoryBuilder.setTimeoutExceptionThreshold( config.timeoutExceptionThreshold );        
		        
		        // Build our connection factory with the defaults we set above
				couchbaseConnectionFactory = CouchbaseConnectionFactoryBuilder.buildCouchbaseConnection( URIs, config.bucket, config.password );
		        				
		        // Create actual client class.  
				couchbaseClientClass = getJavaLoader().create("com.couchbase.client.CouchbaseClient");
			}
			catch(any e) {
				e.printStackTrace();
				instance.logger.error("There was an error creating the CouchbaseClient library: #e.message# #e.detail#", e );
				throw(message='There was an error creating the CouchbaseClient library', detail=e.message & " " & e.detail);
			}
			
			try{
				// Instantiate the client with out connection factory.  This is in a separate try catch to help differentiate between
				// Java classpath issues versus Couchbase connection issues.  
				setCouchbaseClient( CouchbaseClientClass.init( CouchbaseConnectionFactory ) );
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
    	getCouchbaseClient().shutDown( 5, instance.TimeUnitClass.SECONDS );
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
    * @tested
    */
    any function getStoreMetadataReport() output="false" {	
		var md 		= {};
		var keys 	= getKeys();
		var item	= "";
		
		for( item in keys ){
			md[ item ] = getCachedObjectMetadata( item );
		}
		
		return md;
	}
	
	/**
	* Get a key lookup structure where cachebox can build the report on. Ex: [timeout=timeout,lastAccessTimeout=idleTimeout].  It is a way for the visualizer to construct the columns correctly on the reports
	* @tested
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
    * @tested
    */
    any function getKeys() output="false" {
    	
    	ensureViewExists("allKeys");
    	
		// The only reason I'm try/catching this is that the Java exception has an object for the 'type
		// which makes ColdBox's error handing blow up since it tries to use the type as a string.
    	try{
	    	local.allView 		= getCouchbaseClient().getView('CacheBox_allKeys', 'allKeys');
	    	local.query 		= getJavaLoader().create("com.couchbase.client.protocol.views.Query").init();
	    	local.staleClass 	= getJavaLoader().create("com.couchbase.client.protocol.views.Stale");
	    	// Just return the keys, not the docs
	    	local.query.setIncludeDocs( false );
	    	// request fresh data
	    	local.query.setStale( local.StaleClass.FALSE );
	    	// query the view
	    	local.response = getCouchbaseClient().query( local.allView, local.query );
		}
		catch(any e) {
			// log original error.
			instance.logger.error("View Exception: #e.message# #e.detail#", e );
			// Rethrow the error
			throw(message=e.message, detail=e.detail, type="couchbase.view.exception");
		}
		
    	// Were there errors
    	if( arrayLen( local.response.getErrors() ) ){
    		// This will log only and not throw an exception
    		// PLEASE NOTE, the response received may not include all documents if one or more nodes are offline 
	    	// and not yet failed over.  Couchbase basically sends back what docs it _can_ access and ignores the other nodes.
    		handleRowErrors( 'There was an error executing the view allKeys', local.response.getErrors() );
    	}
    	
    	local.iterator = local.response.iterator();
    	local.results = [];
    	
    	while(local.iterator.hasNext()) {
    		arrayAppend( local.results, local.iterator.next().getId() );
    	}
    	
    	return local.results;
	}
	
	/**
    * Ensure that a view exists on the cluster
    * http://tugdualgrall.blogspot.com/2012/12/couchbase-101-create-views-mapreduce.html
    */
    void function ensureViewExists(viewName) {
    	
    	local.designDocumentName = 'CacheBox_' & arguments.viewName;
    	
    	// Couchbase doesn't provide a way to check for DesignDocuments, so try to retrieve it and catch the error.
    	// This should only error the first time and will run successfully every time after.
    	try {
    		getCouchbaseClient().getDesignDocument( local.designDocumentName );	
    	}
    	catch('com.couchbase.client.protocol.views.InvalidViewException' e) {
    		
    		// Create it    		
			local.designDocument = getJavaLoader()
				.create( "com.couchbase.client.protocol.views.DesignDocument" )
				.init( local.designDocumentName );

			// If we start using other views, this function will need to be dynamic based on the view.
			local.mapFunction = '
			function (doc, meta) {
			  emit(meta.id, null);
			}';
			
			// If using reduce function, pass it as third parameter.
			local.viewDesign = getJavaLoader()
				.create( "com.couchbase.client.protocol.views.ViewDesign" )
				.init( arguments.viewName, local.mapFunction );
			local.designDocument.getViews().add( local.viewDesign );
			getCouchbaseClient().createDesignDoc( local.designDocument );
    		
    		// View creation and population is asynchronous so we'll wait a while until it's ready
			local.attempts = 0;
			while(++attempts <= 5) {
				try {
					// Access the view
			    	local.allView 		= getClient().getView(local.designDocumentName,arguments.viewName);
			    	local.query 		= getJavaLoader().create("com.couchbase.client.protocol.views.Query").init();
			    	local.staleClass 	= getJavaLoader().create("com.couchbase.client.protocol.views.Stale");
			    	local.query.setIncludeDocs( false );
			    	// This will force a re-index
			    	local.query.setStale( local.StaleClass.FALSE );
			    	getClient().query( local.allView, local.query );
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
    * @tested
    */
    any function getCachedObjectMetadata(required any objectKey) output="false" {
    	// lower case the keys for case insensitivity
		arguments.objectKey = lcase( arguments.objectKey );
		
		// prepare stats return map
    	local.keyStats = {
			timeout = "",
			lastAccessed = "",
			timeExpires = "",
			isExpired = 0,
			isDirty = 0,
			cas = "",
			dataAge = 0
		};
    	
    	// Get stats for this key from the returned java future
    	local.stats = getCouchbaseClient().getKeyStats( objectKey ).get();
    	if( structKeyExists( local, "stats" ) ){
    		
    		// key_exptime
    		if( structKeyExists( local.stats, "key_exptime" ) and isNumeric( local.stats[ "key_exptime" ] ) ){
    			local.keyStats.timeExpires = dateAdd("s", local.stats[ "key_exptime" ], dateConvert( "utc2Local", "January 1 1970 00:00" ) );
    			local.keyStats.timeout = dateDiff( "n", now(), local.keyStats.timeExpires ); 
    		}
    		// key_last_modification_time
    		if( structKeyExists( local.stats, "key_last_modification_time" ) and isNumeric( local.stats[ "key_last_modification_time" ] ) ){
    			local.keyStats.lastAccessed = dateAdd("s", local.stats[ "key_last_modification_time" ], dateConvert( "utc2Local", "January 1 1970 00:00" ) ); 
    		}
    		// state
    		if( structKeyExists( local.stats, "key_vb_state" ) ){
    			local.keyStats.isExpired = ( local.stats[ "key_vb_state" ] eq "active" ? false : true ); 
    		}
    		// dirty
			if( structKeyExists( local.stats, "key_is_dirty" ) ){
    			local.keyStats.isDirty = local.stats[ "key_is_dirty" ]; 
    		}
    		// data_age
			if( structKeyExists( local.stats, "key_data_age" ) ){
    			local.keyStats.dataAge = local.stats[ "key_data_age" ]; 
    		}
    		// cas
			if( structKeyExists( local.stats, "key_cas" ) ){
    			local.keyStats.cas = local.stats[ "key_cas" ]; 
    		}
    		
    	}
    	
    	return local.keyStats;
	}
	
	/**
    * get an item from cache, returns null if not found.
    * @tested
    */
    any function get(required any objectKey) output="false" {
    	return getQuiet(argumentCollection=arguments);
	}
	
	/**
    * get an item silently from cache, no stats advised: Stats not available on Couchbase
    * @tested
    */
    any function getQuiet(required any objectKey) output="false" {
		// lower case the keys for case insensitivity
		arguments.objectKey = lcase( arguments.objectKey );
		
		try {
    		// local.object will always come back as a string
    		local.object = getCouchbaseClient().get( javacast( "string", arguments.objectKey ) );
			
			// item is no longer in cache, return null
			if( !structKeyExists( local, "object" ) ){
				return;
			}
			
			// return if not our JSON
			if( !isJSON( local.object ) ){
				return local.object;
			}
			
			// inflate our object from JSON
			local.inflatedElement = deserializeJSON( local.object );
			
			// Is simple or not?
			if( structKeyExists( local.inflatedElement, "isSimple" ) and local.inflatedElement.isSimple ){
				return local.inflatedElement.data;
			}
			
			// else we deserialize and return
			if( structKeyExists( local.inflatedElement, "data" ) ){
				return instance.converter.deserializeObject(binaryObject=local.inflatedElement.data);
			}
			
			// who knows what this is?
			return local.object;
		}
		catch(any e) {
			
			if( isTimeoutException( e ) && getConfiguration().ignoreCouchbaseTimeouts ) {
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
    * Not implemented by this cache
    */
    any function isExpired(required any objectKey) output="false" {
		return getCachedObjectMetadata( arguments.objectKey ).isExpired;
	}
	 
	/**
    * check if object in cache
    * @tested
    */
    any function lookup(required any objectKey) output="false" {
    	return ( isNull( get( objectKey ) ) ? false : true );
	}
	
	/**
    * check if object in cache with no stats: Stats not available on Couchbase
    * @tested
    */
    any function lookupQuiet(required any objectKey) output="false" {
		// not possible yet on Couchbase
		return lookup( arguments.objectKey );
	}
	
	/**
    * set an object in cache and returns an object future if possible
    * lastAccessTimeout.hint Not used in this provider
    * @tested
    */
    any function set(required any objectKey,
					 required any object,
					 any timeout=instance.configuration.objectDefaultTimeout,
					 any lastAccessTimeout="0", // Not used for this provider
					 any extra) output="false" {
		
		var future = setQuiet(argumentCollection=arguments);
		
		//ColdBox events
		var iData = { 
			cache				= this,
			cacheObject			= arguments.object,
			cacheObjectKey 		= arguments.objectKey,
			cacheObjectTimeout 	= arguments.timeout,
			cacheObjectLastAccessTimeout = arguments.lastAccessTimeout,
			couchbaseFuture 	= future
		};		
		getEventManager().processState( state="afterCacheElementInsert", interceptData=iData, async=true );
		
		return future;
	}	
	
	/**
    * set an object in cache with no advising to events, returns a couchbase future if possible
    * lastAccessTimeout.hint Not used in this provider
    * @tested
    */
    any function setQuiet(required any objectKey,
						  required any object,
						  any timeout=instance.configuration.objectDefaultTimeout,
						  any lastAccessTimeout="0", // Not used for this provider
						  any extra=structNew()) output="false" {
		
		// lower case the keys for case insensitivity
		arguments.objectKey = lcase( arguments.objectKey );
		
		// "quiet" "not implemented by Couchbase yet
		var future = "";
		
		// create storage element
		var sElement = {
			createdDate = dateformat( now(), "mm/dd/yyyy") & " " & timeformat( now(), "full" ),
			timeout = arguments.timeout,
			metadata = ( structKeyExists( arguments.extra, "metadata" ) ? arguments.extra.metadata : {} ),
			isSimple = isSimpleValue( arguments.object ),
			data = arguments.object
		};
		
		// Do we need to serialize incoming obj
		if( !sElement.isSimple ){
			sElement.data = instance.converter.serializeObject( arguments.object );
		}
		
		// Serialize element to JSON
		sElement = serializeJSON( sElement );

    	try {
    		
			// You can pass in a net.spy.memcached.transcoders.Transcoder to override the default
			if( structKeyExists( arguments, 'extra' ) && structKeyExists( arguments.extra, 'transcoder' ) ){
				future = getCouchbaseClient()
					.set( javaCast( "string", arguments.objectKey ), javaCast( "int", arguments.timeout*60 ), sElement, extra.transcoder );
			}
			else {
				future = getCouchbaseClient()
					.set( javaCast( "string", arguments.objectKey ), javaCast( "int",arguments.timeout*60 ), sElement );
			}
		
		}
		catch(any e) {
			
			if( isTimeoutException( e ) && getConfiguration().ignoreCouchbaseTimeouts) {
				// log it
				instance.logger.error( "Couchbase timeout exception detected: #e.message# #e.detail#", e );
				// return nothing
				return;
			}
			
			// For any other type of exception, rethrow.
			rethrow;
		}
		
		return future;
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
		var future = getCouchbaseClient().flush();		
				 
		var iData = {
			cache			= this,
			couchbaseFuture = future
		};
		
		// notify listeners		
		getEventManager().processState("afterCacheClearAll",iData);
	}
	
	/**
    * clear an element from cache and returns the couchbase java future
    * @tested
    */
    any function clear(required any objectKey) output="false" {
		// lower case the keys for case insensitivity
		arguments.objectKey = lcase( arguments.objectKey );
		
		// Delete from couchbase
		var future = getCouchbaseClient().delete( arguments.objectKey );
		
		//ColdBox events
		var iData = { 
			cache				= this,
			cacheObjectKey 		= arguments.objectKey,
			couchbaseFuture		= future
		};		
		getEventManager().processState( state="afterCacheElementRemoved", interceptData=iData, async=true );
		
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
	
	private boolean function isTimeoutException(required any exception){
    	return (exception.type == 'net.spy.memcached.OperationTimeoutException' || exception.message == 'Exception waiting for value' || exception.message == 'Interrupted waiting for value');
	}
	
	/**
    * Deal with errors that came back from the cluster
    * rowErrors is an array of com.couchbase.client.protocol.views.RowError
    */
    private any function handleRowErrors(message, rowErrors) {
    	local.detail = '';
    	for(local.error in arguments.rowErrors) {
    		local.detail &= local.error.getFrom();
    		local.detail &= local.error.getReason();
    	}
    	
    	// It appears that there is still a useful result even if errors were returned so
    	// we'll just log it and not interrupt the request by throwing.  
    	instance.logger.warn(arguments.message, local.detail);
    	//Throw(message=arguments.message, detail=local.detail);
    	
    	return this;
    }

}