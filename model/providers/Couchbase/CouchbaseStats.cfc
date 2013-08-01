/**
********************************************************************************
Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldbox.org | www.luismajano.com | www.ortussolutions.com
********************************************************************************
Author: Brad Wood, Luis Majano
Description:
	
Stats for Couchbase Provider
*/
component implements="coldbox.system.cache.util.ICacheStats" accessors="true"{
	
	// The cache provider this stats are linked to
	property name="cacheProvider" serializable="false";

	/**
	* Constructor
	*/
	CouchBaseStats function init( cacheProvider ) output=false{
		
		setCacheProvider( arguments.cacheProvider );
		
		// Stats are represented as a hashmap that use a java.net.InetSocketAddress as the key.  However, Railo wants to keep autoconverting the 
		// keys to a string which is keeping me from being able to use the map[key] syntax.  Instead get an interator of the values and convert to array
		variables.instance.cacheStats = arguments.cacheProvider.getCouchBaseClient().getStats().values().toArray();
		return this;
	}

	any function getCachePerformanceRatio() output=false{
		var hits 		= getHits();
		var requests 	= hits + getMisses();
		
	 	if ( requests eq 0){
	 		return 0;
		}
		
		return (hits/requests) * 100;
	}
	
	any function getObjectCount() output=false{
		return getAggregateStat('vb_active_curr_items');
	}
	
	void function clearStatistics() output=false{
		// not yet implemented by CouchBase
	}
	
	any function getGarbageCollections() output=false{
		return 0;
	}
	
	any function getEvictionCount() output=false{
		return 0;
	}
	
	any function getHits() output=false{
		return getAggregateStat( 'get_hits' );
	}
	
	any function getMisses() output=false{
		return getAggregateStat( 'get_misses' );
	}
	
	any function getLastReapDatetime() output=false{
		return "";
	}
	
	/************************************** private *********************************************/
	
	private any function getAggregateStat(string statName) {
		local.result = 0;
		
		// For each server, loop and add up
		for(local.server in variables.instance.cacheStats){
			// make sure the stat exists
			if( structKeyExists( local.server, arguments.statName ) ){
				local.result += val( local.server[ arguments.statName ] );	
			}
		}
		
		return local.result;
		
	}
	
}