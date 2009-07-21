REBOL [
	Title: "Cheyenne Admin service"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Version: 1.0
	Date: 01/12/2007
]

install-service [
	name: 'admin
	port-id: 10000
	scheme: 'udp
	verbose: 0
	
	on-raw-received: func [data][
		if client/remote-ip <> 127.0.0.1 [exit]
		data: to string! data
		
		switch data/1 [
			#"Q" [
				if verbose > 0 [log/info "clean exit..."]
				uniserve/services/httpd/on-quit
				stop-events
			]		
			#"R" [
				uniserve/services/httpd/on-reload
			]
			#"W" [
				uniserve/services/task-master/on-reset
			]
		]
	]
]