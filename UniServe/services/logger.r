REBOL [
	Title: "Logger service"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Date: 02/01/2009
	Version: 1.0.0
	Purpose: "UniServe's remote message logging service"
]

install-service [
	name: 'Logger
	port-id: 9802
	verbose: 0
	
	trace-file: join system/options/path %trace.log
	error-file: join system/options/path %error.log
	
	add-head: func [value][head insert value debase/base to-hex length? value 16]
	
	on-new-client: does [stop-at: 4]
	
	process: func [data /local file][
		file: get pick [error-file trace-file] data/1 = #"E"
		write/append/direct file next data
	]
	
	on-received: func [data][
		 either client/user-data = 'head [
			if verbose > 0 [log/info join "new request: " to string! data]
			process data
			client/user-data: none
			stop-at: 4
		][
			client/user-data: 'head
			stop-at: 1 + to integer! data 4
		]
	]
]