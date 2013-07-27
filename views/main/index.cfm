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
			XML = XMLParse('<root><item attr1="value1" attr2="value3" /><item attr1="value1" attr2="value3" /><item attr1="value1" attr2="value3" /></root>'),
			CFC = event
		};
		
		i=0;
		// Tested this up to 500K iterations.  
		iterations = 10;
	
		sTime = getTickCount();
		while(++i<iterations) {
			cb.set(i,i);
		}
		setsTime = getTickCount() - sTime;
		writeOutput( "<h2>Sets Time: #setsTime#ms<h2><br>");
		//writeOutput( "<h2>Keys:<h2><br>#cb.getKeys().toString()#");
		//abort;
		i=0;
		sTime = getTickCount();
			while(++i<iterations) {
				cb.get(i);
			}
		getsTime = getTickCount() - sTime;
		writeOutput( "<h2>Gets Time: #getsTime#ms<h2><br>");
	
		// Careful calling this.  It is asynch and can take a while to run so you might not be able to set anything into the  
		// cache for a few minutes until it is still deleting.  (If you try, you will get nothing back so I assume it is still "deleting")
		//cb.clearAll();
				
		for(key in testData) {
			cb.set(key,testData[key]);
		}		

	</cfscript>

	<cfloop collection="#testData#" item="key">
		#key#: <cfdump expand="false" var="#cb.get(key)#">
	</cfloop>
	
	<!--- This works well, but be wary of a monster dump if you have thousands of documents in the bucket. --->
	<!---<cfdump var="#cb.getKeys()#">--->
		
</cfoutput>
