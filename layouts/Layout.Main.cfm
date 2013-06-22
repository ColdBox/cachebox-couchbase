<cfoutput>
	
	<cfset HTMLHelper = getPlugin("HTMLHelper")>
	#HTMLHelper.docType()#
	<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
		<head>
			<title>CouchBase CacheBox Provider test page</title>
		</head>
		<body>
			#renderView()#
		</body>
	</html>
</cfoutput>