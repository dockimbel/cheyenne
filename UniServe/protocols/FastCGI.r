REBOL [
	Title: "FastCGI client protocol"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Version: 1.2.0
	Date: 10/12/2007
]

do-cache uniserve-path/libs/headers.r

install-protocol [
	name: 'FastCGI
	port-id: 8000
	
	seq-id: 1
	out: make string! 1024 * 10
	;req-ctx: none					; not re-entrant for multiple fastcgi connections !
 	
	;--- Low-level I/O ---
	
	b0: b1: b2: b3: int: int24: mark: bytes: expected: none

	read-byte: [copy byte skip (byte: to integer! to char! :byte)]
	read-nbytes: [mark: (bytes: copy/part mark expected mark: skip mark expected) :mark]
	read-int: [
		read-byte (b1: byte)
		read-byte (b0: byte	int: b0 + (256 * b1))
	]
	read-int24: [
		read-byte (b2: byte)
		read-byte (b1: byte)
		read-byte (b0: byte	int24: b0 + (256 * b1) + (65536 * b2))
	]

	write-int16: func [value [integer!]][
		join to char! value / 256 to char! value // 256 
	]
		
	;--- ---
	
	defs: [
		misc [
			header-len	8 ; Number of bytes in a fcgi_header
			version		1 ; Value for version component of fcgi_header
			null-request-id	0
		]
		role [
			1	begin-request
			2	abort-request
			3	end-request
			4	params
			5	stdin
			6	stdout
			7	stderr
			8	data
			9	get-values
			10	get-values-result
			11	unknown-type
		]
		mask [
			keep-conn  1 ; Mask for flags component of FCGI_BeginRequestBody
		]
		begin-role [
			1	responder
			2	authorizer
			3	filter
		]
		end-role [
			0	request-complete
			1	cant-mpx-conn
			2	overloaded
			3	unknown-role
		]
		values [
			"FCGI_MAX_CONNS"  ""
			"FCGI_MAX_REQS"   ""
			"FCGI_MPXS_CONNS" ""
		]
	]
	
	decode-role: func [value [integer!]][
		any [select defs/role value 'unknown]
	]

	encode-role: func [value [word!]][
		first back find defs/role value
	]

	decode-begin-role: func [value [integer!]][
		any [select defs/begin-role value 'unknown]
	]
	
	decode-end-role: func [value [integer!]][
		any [select defs/end-role value 'unknown]
	]
	
	make-nv-pairs: func [data /local len][
		clear out	
		foreach-nv-pair data [
			if value [	
				insert tail out to char! length? name: form name
				insert tail out either 127 < len: length? value [
					#{80000000} or debase/base to-hex len 16
				][
					to char! len
				]
				insert tail out name
				insert tail out value
			]
		]
		out
	]
	
	make-record: func [content [any-string!] type [word!] id [integer!] /local sz][
		head insert/part tail rejoin [
			#"^(01)"
			to char! encode-role type
			write-int16 id
			write-int16 sz: min 65535 length? content
			#"^(00)"
			#"^(00)"
		] content sz
	]
	
	send-cmd: func [cmd [word!] id /ext data][
		write-server switch cmd [
			begin	[make-record #{0001010000000000} 'begin-request id]
			params	[make-record any [all [ext make-nv-pairs data] ""] 'params id]
			stdin	[make-record any [data ""] 'stdin id]
			values	[make-record make-nv-pairs defs/values 'get-values id]
		]
	]
	
	CGI-format: func [blk][
		forall blk [
			change blk join "HTTP_" replace/all uppercase form blk/1 #"-" #"_"
			blk: next blk
		]
		head blk
	]
	
	make-new-request: func [id][
		repend server/user-data/queue [
			id context [
				state: 'header
				padding: 0
				stdout: stderr: type: none
			]
		]
	]
	
	stop-at: defs/misc/header-len
	
	on-connected: does [
		set-modes server [keep-alive: true]
		server/user-data: context [
			req-ctx: none
			queue: make block! 16
		]
		on-ready server
	]
	
	on-received: func [data /local su req len][
;foreach [id req] server/user-data/queue [print [id type? req]]
		su: server/user-data
		req: any [
			su/req-ctx
			all [
				server/id: (to integer! data/3) * 256 + data/4
				su/req-ctx: select su/queue server/id
			]
		]
		switch req/state [
			header	[
				req/type: decode-role second data
				req/padding: to integer! pick data 7
				len: (to integer! data/5) * 256 + data/6 + req/padding
				if not zero? len [
					stop-at: len
					req/state: 'content
				]
			]
			content [	
				switch req/type [
					stdout [
						if not req/stdout [req/stdout: make string! 1024 * 10]
						either zero? req/padding [
							append req/stdout data
						][
							insert/part tail req/stdout data stop-at - req/padding
						]
					]
					stderr [
						if not req/stderr [req/stderr: make string! 1024 * 10]
						either zero? req/padding [
							append req/stderr data
						][
							insert/part tail req/stderr data stop-at - req/padding
						]
					]
					end-request [
						if not zero? len: to integer! data/5 [
							log/warn reform ["response error:" decode-end-role len]
						]
						on-response server req/stdout req/stderr
						remove/part back find su/queue su/req-ctx 2
						;remove/part find server/user-data server/id 2
						su/req-ctx: none
					]
					get-values-result [
						su/req-ctx: none
						?? data
					]
				]
				req/state: 'header
				stop-at: defs/misc/header-len
			]
		]
	]
	
	new-insert-port: func [port req [object!] /local id][
		make-new-request id: port/id
		send-cmd 'begin id	
		
		send-cmd/ext 'params id reduce [
			"SERVER_SOFTWARE"	"Cheyenne/1.0"
			"SERVER_NAME"		system/network/host
			"GATEWAY_INTERFACE"	"CGI/1.1"
			"SERVER_PORT" 		form req/client/local-port
			"REQUEST_METHOD"	req/method
			"PATH_INFO" 		at req/url 1 + length? req/script
			"PATH_TRANSLATED"	req/path
			"SCRIPT_FILENAME"	req/path
			"REQUEST_URI"		req/url
			"SCRIPT_NAME" 		req/script
			"QUERY_STRING"		req/query
			;"REMOTE_HOST" 		none
			"REMOTE_ADDR" 		form req/client/remote-ip
			"AUTH_TYPE" 		req/auth-type
			"REMOTE_USER" 		req/user
			;"REMOTE_IDENT" 	none
			"CONTENT_LENGTH"	req/cnt-length
			"CONTENT_TYPE"		req/cnt-type
		]
		send-cmd/ext 'params id CGI-format req/headers
		send-cmd 'params id
		if req/content [
			while [positive? length? req/content][
				send-cmd/ext 'stdin id req/content
				req/content: skip req/content 65535
			]
		]
		send-cmd 'stdin id
		;seq-id: seq-id + 1			; TBD: decide to manage IDs at the protocol level, or not
	]
	
	on-close-server: has [req su][
;print "closing, trying to catch last one"	
		su: server/user-data
		if not empty? su/queue [	; try to finish the last request if any
			server/id: su/queue/1
			req: su/queue/2
;print ["found ID : " server/id]
			if any [req/stdout req/stderr][
				on-response server req/stdout req/stderr
			]
		]
		su/req-ctx: none	; ?? really useful ??
		on-closed server
		false
	]
	
	events: [
		on-response	; [port [port!] out [string!] err [string! none!]]
		on-ready 	; [port!]
		on-closed	; [port!]
	]
]

fcgi-job-class: context [
	id: url: info: path: script: query: auth-type: user: 
	headers: content: cnt-length: cnt-type: client: none
	method: "GET"
]
