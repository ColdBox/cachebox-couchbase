<cfoutput>

<h1>CouchBase CacheBox Provider Test</h1>

	<cfset cb = getModel(dsl="cacheBox:couchBase")>
	<cfscript>
			
		testData = {
			string = "foobar",
			number = 3.14,
			JSON = '{"foo":"bar","loo":5,"subStruct":{"goo":"smar"},"subArray":[1,2,3,4,5]}',
			array = ['a','b','c','d','e'],
			struct = {"foo":"bar","loo":5,"subStruct":{"goo":"smar"},"subArray":[1,2,3,4,5]},
			//XML = toString( XMLParse('<root><item attr1="value1" attr2="value3" /><item attr1="value1" attr2="value3" /><item attr1="value1" attr2="value3" /></root>') )
			CFC = new couchbaseApp.config.CacheBox()
		};
		
		i=0;
		// Tested this up to 500K iterations.  
		iterations = 10;
		writeOutput("<p>Iterations: #iterations#</p>");
		
		sTime = getTickCount();
		while( ++i < iterations) {
			cb.set( i, i );
		}
		setsTime = getTickCount() - sTime;
		writeOutput( "<p>Sets Time: #setsTime#ms</p>");
		//writeOutput( "<h2>Keys:<h2><br>#cb.getKeys().toString()#");
		//abort;
		i=0;
		sTime = getTickCount();
			while(++i<iterations) {
				cb.get(i);
			}
		getsTime = getTickCount() - sTime;
		writeOutput( "<p>Gets Time: #getsTime#ms</p>");
	
		// Careful calling this.  It is asynch and can take a while to run so you might not be able to set anything into the  
		// cache for a few minutes until it is still deleting.  (If you try, you will get nothing back so I assume it is still "deleting")
		//cb.clearAll();
				
		for(key in testData) {
			cb.set( key, testData[ key ] );
		}	

	</cfscript>

	<cfloop collection="#testData#" item="key">
		#key#: <cfdump expand="false" var="#cb.get( key )#">
	</cfloop>
	
	<cfset runEvent("main.eventTest")>	
	<cfset runEvent("main.viewTest")>
	
	<!--- This works well, but be wary of a monster dump if you have thousands of documents in the bucket. --->
	<!---<cfdump var="#cb.getKeys()#">--->
	
	
	<cfset cb.setJSON( 'myJSON', '{"foo":"bar","doo":[1,2,3,4,5]}' )>
	<cfdump var="#cb.getJSON( 'myJson' )#">
	
				
</cfoutput>
