REBOL []

install-HTTPd-extension [
	name: 'mod-action
	
	order: [
		set-mime-type	normal
		access-check	normal
		make-response	normal
		reform-headers	normal
		logging			last
		task-done		last
		task-failed		last
	]
	
	dyn-types: make block! 8
	
	declined?: func [req][not select dyn-types req/in/ext]
	
	on-reload: does [
		clear dyn-types
	]
	
	set-mime-type: func [req][
		if declined? req [return none]
		req/out/mime: 'text/html
		true
	]
	
	access-check: func [req /local info mdate][
		; --- This phase is redefined to avoid Last-Modified header generation
		; --- from mod-static (inappropriate here)
		
		if declined? req [return none]
		
		; --- Test if the file can be read by Uniserve		
		unless req/file-info: info? req/in/file [
			req/out/code: 400
		]
		true
	]
	
	make-response: func [req /local mod msg][
		; --- Decline unless dynamic type
		unless mod: select dyn-types req/in/ext [return none]
		
		service/module: mod
		msg: remold [
			to lit-word! 'cfg req/cfg
			to lit-word! 'in req/in
			to lit-word! 'ip service/client/remote-ip
			to lit-word! 'port service/client/local-port
		]
		service/do-task msg req
		true
	]
	
	reform-headers: func [req /local roh][
		if declined? req [return none]
		
		if req/out/code = 200 [
			roh: req/out/headers
			unless find roh 'Cache-Control [
				;h-store roh 'Cache-Control "private, max-age=0"
				h-store roh 'Cache-Control "no-cache, no-store, max-age=0, must-revalidate"
			]
			unless find roh 'Pragma [
				h-store roh 'Pragma "no-cache"
			]
			unless find roh 'Expires [
				h-store roh 'Expires "-1"
			]
			false
		]
	]
	
	logging: func [req][
		none
	]
	
	task-done: func [req /local res value data][
		data: req/out/content

		either "HTTP" = copy/part data 4 [
			;--- Non Parsed Header output ---
; TBD: test this code branch
			req/out/header-sent?: yes
		][
			;--- Parsed Header output ---					
			res: service/parse-headers data req/out	
			either first res [
				unless empty? data [
					if cr = first res/2 [data: skip res/2 2]
					if lf = first res/2 [data: next res/2]
					req/out/content: copy data
				]			
			][
				req/out/content: "<html>CGI Headers Error</html>"
			]
			any [
				all [
					value: select req/out/headers 'Status
					req/out/status-line: rejoin [
						"HTTP/1.1 " trim/tail value crlf
					]
					h-store req/out/headers 'Status none
				]
				all [
					select req/out/headers 'Location
					req/out/code: 302
				]
				req/out/code: 200
			]
		]
		service/process-queue
		true
	]
	
	task-failed: func [req][
		req/out/code: 500
		service/process-queue
		true
	]
	
	words: [
		;--- associate a file extension with an external handler for bg processing
		bind-extern: [word!] 'to [word! | block!] in globals do [
			use [data][
				foreach ext to-block args/2 [
					data: reduce [ext args/1]
					append service/mod-list/mod-action/dyn-types data
					append service/handlers data
				]
			]
		]
		
		;--- list libraries to be loaded by workers processes
		worker-libs: [block!] in globals
		
		;--- allow domain or application specific local parameters (free-form content)
		locals: [block!] in main
		
		;-- switches REBOL CGI scripts to FastCGI-like mode
		fast-rebol-cgi: in globals
	]
]