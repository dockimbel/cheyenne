REBOL [
	file: %unit.r
	author: "Maxim Olivier-Adlhoch"
	date: 2011-04-24
	version: 0.6.0
	title: "Basic test unit, defines the core testing mechanism.  Implements all HTTP testing requirements."
	
	notes: {
		I'd like to state that this unit testing engine is writen in a style which is
		intentionally simple, explicit and void of any tricks.
		
		The unit engine itself, must be easy to debug and fix if any issue is found.
		
		It is purpose-built to manage client-server requests using the http protocol over TCP.
		
		I have separated many of the steps in handling a request into separate functions and data items,
		specifically to make each one simple to track and allow as little side-effects as possible.
		
		ALL http message packing and unpacking follows the specifications in the appropriate RFCs, down to
		each exact byte and whitespace allowance.  Generally, when some data parsing is required, the 
		actual BNF grammar is copied directly from the RFC and converted to REBOL's own PARSE dialect.
		
		This unit testing engine puts absolutely no effort in optimizing speed or memory use.  In fact
		it stores a lot more information than is required, in order to allow just about any type of assertion
		to be performed related to the complete http request from start to stop.
		
		Application tracing is provided by the vprint module which allows hierarchical and programmable
		control over application output.  Logging is also made transparently, allowing you to use the same
		application tracing on screen AND/OR in a file, by simply setting up the vprint logging parameters.
		
	}

	license-type: 'MIT
	license:      {Copyright © 2011 Maxim Olivier-Adlhoch.

		Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
		and associated documentation files (the "Software"), to deal in the Software without restriction, 
		including without limitation the rights to use, copy, modify, merge, publish, distribute, 
		sublicense, and/or sell copies of the Software, and to permit persons to whom the Software 
		is furnished to do so, subject to the following conditions:
		
		The above copyright notice and this permission notice shall be included in all copies or 
		substantial portions of the Software.}
		
	disclaimer: {THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
		INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
		PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
		FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
		ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
		THE SOFTWARE.}

]


do %vprint.r
do %mezz.r
do %classes.r
do %tests.r



;------------------------
; this is used after all setup has been done
; to supply the port-spec with default values
; for any property which was not explicitely set.
;
;- DEFAULT-PORT-SPEC [
default-port-spec: context [

	;-    scheme:
	scheme: 'http

	;-        host:
	; server's DNS name or an IP address 
	host: "localhost"
	
	;-        port-id:
	; tcp port to use on connection.
	port-id: 80
	
	;-        uri:
	; the Uniform Resource Identifier used in request (complete path & target part of a URL).
	uri: none
	
	;-        path:
	path: none

	;-        target:
	target: none
	
	
	;-        user:
	; when connecting, do we need a user-name
	user: none
	
	;-        pass:
	; when connecting, do we need a password
	pass: none
]
;-    ]




;- !UNIT
; this is the core test unit.
;
; its defined as a single tcp/ip connection, sending an http request, and extracting the result.
;
; it offers comparison methods, and reporting tools.
;
; the !unit is wrapped into other test-suite tools which use it to create specific unit tests.
;
; note that by default, the unit test engine DOES NOT use the rebol http scheme, because we require
; precise and explicit control and validation over the whole http request/response of the server
; we are communicating with.
;
; the unit has methods to manage successive calls by using a previous unit response as the source
; for the next call.
;------
!unit: context [

	;-    UNIT PROPERTIES

	;-    name:
	; the name of this test, used as a label for other tools to refer to it.
	name: 'http

	;-    port-spec
	port-spec: none
	
	
	;-    parameters:
	;
	; test-specific data used to setup a single test.
	parameters: none
	
	
	;-    http-method:
	;
	; how do we construct & post the request. (currently supports HEAD, GET & POST)
	http-method: 'GET
	
	
	;-    http-version:
	; changes how various http-handling methods manage requests and responses.
	http-version: 1.1
	
	
	;-    new-line-char:
	NEW-LINE-CHAR: CRLF
	
	
	;-    port:
	; once connected to a server, this stores the port object.
	port: none
	

	;-    request:
	; the allocated request for a single connection attempt.
	request: none
	
	
	
	;-    response:
	; data collected within load-response on http reply is stored here.
	;
	; this is the low-level break up of the http data before its analysed by the
	; unit testing methods.
	response: none
	
	
	;-    test-passed?:
	;
	; when a test is performed on this unit, the result
	; will be copied here.
	;
	; note that if you perform multiple calls to pass?() then only the
	; latest result is stored.
	test-passed?: true
	
	
	;-    test-report:
	;
	; when a test is performed on this unit, the report
	; will be stored here.
	;
	; note that ALL reports are tabulated within the same block.
	;
	; test reports are usefull to do comparisons on the results of the tests.
	;
	; when report storing and file comparison will be enabled, you will be able to 
	; compare tests with previous runs, to see if any changes have occured with 
	; previous test runs.    
	;
	; this is usefull to perform automatic regression tests...
	;
	; note that the test-report can be used by all phases of the request,
	; and is the only way to be aware of some errors, like connection errors.
	;
	; also note that there is no specific format to the test-report,
	; it really is just a log of any and all newsworthy events which occured
	; with this unit.
	test-report: []
	
	
	
	;-  
	;-    LOW-LEVEL METHODS
	
	
	
	;-----------------
	;-    connect()
	;
	; does the tcp connection with server
	;-----------------
	connect: func [
		/local success?
	][
		vin [{connect()}]
		unless attempt [
			port: open/binary/no-wait tcp-url
			success?: true
		][
			append test-report reduce ['connection-failed  http-url]
		
		]
		vout
		success?
	]
	
	
	
	
	;-----------------
	;-    send()
	;
	; send data through our currently allocated port
	;
	; you are responsible for properly converting any rebol data to a string or binary.
	;-----------------
	send: func [
		data [binary! string!]
		/local err
	][
		vin [{send()}]
		if error? err: try [
			insert port data
			none
		][
			err: mold disarm err
		]
		vout
		
		; if an error occured, err will hold the string with the disarmed error
		err
	]

	;-----------------
	;-    receive()
	;
	; receive response data through our currently allocated port
	;
	; the receive function is simply concerned with waiting for all data to arrive 
	; and closing the port
	;-----------------
	receive: func [
		data [binary! string!]
		/local err
	][
		vin [{send()}]
		if error? err: try [
			insert port data
			none
		][
			err: mold disarm err
		]
		vout
		
		; if an error occured, err will hold the string with the disarmed error
		err
	]
	
	
	
	;-  
	;-    UNIT METHODS
	

	
	;-----------------
	;-    init-unit()
	;
	; initialize unit-dependent data required by this unit.
	;-----------------
	init-unit: func [
	][
		vin [{init-unit()}]
		vout
	]
	
	
	;-----------------
	;-    init()
	;
	; initialize core run-time data required by ALL units.
	;-----------------
	init: func [
	][
		vin [{init()}]
		
		; make sure this test doesn't affect other test.
		port-spec: make !http-port-spec []
		request: make !http-request [init]
		response: make !http-response [init]
		
		; do unit specific initialization.
		init-unit
		vout
	]
	
	;-----------------
	;-    http-url()
	;-----------------
	http-url: func [
		/local usr
	][
		[scheme-part user-part host-part path-part file-part tag-part]
		usr: any  [
			all [ port-spec/pass port-spec/user rejoin [port-spec/user ":" port-spec/pass "@"] ]
			all [ port-spec/user rejoin [port-spec/user "@"] ]
			""
		]
		rejoin [http:// usr port-spec/host ":" port-spec/port-id port-spec/uri] 
	]
	
	;-----------------
	;-    tcp-url()
	;-----------------
	tcp-url: func [][
		rejoin [tcp:// port-spec/host ":" port-spec/port-id] 
	]
	
	
	
	;-----------------
	;-    set-url()
	;-----------------
	set-url: func [
		url [url!]
		/local ctx
	][
		vin [{set-url()}]
		ctx: split-url url
		
		port-spec/port-id: any [ctx/port-id port-spec/port-id default-port-spec/port-id]
		port-spec/host: any [ctx/host port-spec/host default-port-spec/host]
		port-spec/uri: any [
			all [
				ctx/target
				ctx/path
				join dirize ctx/path ctx/target
			]
			all [
				ctx/path
				dirize ctx/path
			]
			port-spec/uri
			default-port-spec/uri
		]
		port-spec/scheme: any [ctx/scheme port-spec/scheme default-port-spec/scheme]
		
		port-spec/user: any [ctx/user port-spec/user default-port-spec/user]
		port-spec/pass: any [ctx/pass port-spec/pass default-port-spec/pass]
		
		v?? ctx
		
		v?? port-spec
		
		
		vout
	]
	
	
	
	;-----------------
	;-    build-http-content()
	;
	; using current unit data & request/content params, construct the binary which will be posted (if any).
	;
	; this function is only ever called when the request is a POST.
	;
	; if the request/content-buffer is already filled up somehow, this function does nothing.
	;
	; you can also overide this function to provide custom post mechanisms to a funky unit test.
	;-----------------
	build-http-content: func [
		/local param
	][
		vin [{build-http-content()}]
		
		if all [
			object? request/params
			none? request/content-buffer
		][
			request/content-buffer: clear #{}  ; we reuse the same buffer, which will auto-grow as queries are performed. {}
			foreach param words-of request/params [
				append request/content-buffer rejoin [#{} to-string param "=" request NEW-LINE-CHAR] ;{}
			]
		]

		vout
	]
	
	
	
	;-----------------
	;-    build-http-header()
	;
	; using current data, build the header, ready to send() over the wire.
	;-----------------
	build-http-header: func [
		/local word words values hdr srh
	][
		vin [{unit/build-http-header()}]
		
		; this isn't an actual header "field" but the first line of the http request
		; which defines the method, URI and scheme version used.
		;
		; <RFC 1945 section 5.1>
		request/request-line: rejoin [ #{} http-method " " url-encode port-spec/uri " HTTP/" http-version CRLF ] ; { }
		request/header-buffer: copy request/request-line
		
		switch http-method [
			POST [
				; setup any dynamic fields in the header (usually based on url and content)
				request/header: make request/header [
					Content-Type: request/content-type
					Content-Length: to-string length? request/content-buffer
				]
			]
			
			GET HEAD [
				; no special fields for GET or HEAD
			]
		]
		
		
		; NOTE: CHEYENNE RFC discrepancy.  if http 1.0 is used and Host field is given, the server will 
		;       react just like a 1.1 request.
		if http-version = 1.1 [
			request/header: make request/header [
				Host: to-string port-spec/host
			]
		]
		
		
		; apply user overides if any
		if object? request/user-header [
			request/header: make request/header request/user-header
		]
		
		
		words: words-of request/header
		values: values-of request/header
		
		merge words values
		
		foreach [word value] words [
			insert tail request/header-buffer reduce [word ": " value CRLF]
		]
	
		; GC clean exit
		word: words: values:  none
		vout
		none
	]
	
	
	
	
	
	;-----------------
	;-    destroy-unit()
	; 
	; erase unit-data which will not be managed by destroy()
	;
	; usually you don't need to put any code here, since destroy() flushes the complete
	; object (puts everything to none)
	;-----------------
	destroy-unit: func [
	][
		vin [{destroy-unit()}]
		vout
	]
	
	
	;-----------------
	;-    destroy()
	;
	; completely erase all data used by this test.
	;-----------------
	destroy: func [
		/local
	][
		vin [{destroy()}]
		destroy-unit
		foreach word words-of self [
			self/:word: none
		]
		vout
	]
	
	;-----------------
	;-    send-request()
	;-----------------
	send-request: func [
	][
		vin [{send-request()}]
		vprobe type? request/header-buffer
		request/time: now/precise
		switch http-method [
			GET HEAD [
				send request/header-buffer
				send CRLF
			]
			POST [
				send request/header-buffer
				send CRLF
				send request/content-buffer
			]
		]
		vout
	]
	
	;-----------------
	;-    receive-request()
	;-----------------
	receive-request: func [
		/local pkt
	][
		vin [{receive-request()}]

		until [
			if pkt: copy port [
				;prin "."
				either empty? pkt [
					wait 0.1
				][
					vprint to-string pkt
					append response/buffer pkt
				]
			]
			none? pkt
		]
		response/time: now/precise
		vprobe length? response/buffer
		vout
	]
	
	
	;-----------------
	;-    parse-response()
	;
	; parse the response/binary to extract information for later analysis.
	;-----------------
	parse-response: func [
		/local val status tkn
	][
		vin [{parse-response()}]
		response/success?: false
		
		vprobe to-string response/buffer
		
		if binary? response/buffer [
			response/success?: parse/all response/buffer [
				; parse status-line
				copy status [
					
					copy val ["HTTP/" =digits= =.= =digits=] (response/status-version: load val)
					=SP=
					copy val [=digits=] (response/status-code: load val)
					=SP=
					copy val some [
						=STATUS-TEXT=
					](response/status-text: val)
					
				] =CRLF= (response/status-line: status)
				; headers
				some [
					copy tkn some [=token=] ":" any [=white-space=] copy val [some =header-content=] =CRLF= (
						response/header: make response/header reduce [
							to-set-word tkn
							val
						]
					)
				]
				=CRLF=
				copy val to end (response/content: to-string val)
			]
		]
		vout
	]
	
	
	
	
	;-----------------
	;-    execute()
	;-----------------
	; this is the actual code you execute when performing the test.
	;
	; at this point the unit must be all setup.
	;
	; after execute is run, you can use unit/response directly.
	;
	; in order to determine the validity of the test, use various
	; compare & report methods on the unit after execute().
	;-----------------
	execute: func [
		/local content header
	][
		vin "Execute()"
		vprobe request
		
		if http-method = 'POST [
			build-http-content
		]
		
		build-http-header
		
		vprobe to-string request/request-line
		vprobe to-string request/header-buffer
		vprobe to-string request/content-buffer
		
		if connect [
			send-request
			receive-request
			parse-response
		]
		vout
	]
	
	
	;-----------------
	;-    pass?()
	;
	; does the unit meet all test criteria?
	;-----------------
	pass?: func [
		tests [block!]
		/report report-blk [block! none!] "returns a report on all tests"
		/stop "stop at first failure, otherwise it tries all tests."
		/local data test test-func success? result blk
	][
		vin [{pass?()}]
		blk: copy []
		
		;------------
		; we only performed tests if the actual http request responded
		; correctly at its lowest level (headers aren't malformed).
		;------------
		result: true? if response/success? [
			result: true
			foreach [test data] tests [
				either do-test: select unit-tests test [
					success?: true = do-test self data blk
				][
					append blk reduce [to-set-word test #invalid-test]
				]
				
				; will stay true until one test fails
				result: result AND success?
				
				if all [
					not success?
					stop
				][
					break
				]
			]
			
			; improve report readability
			new-line/skip blk true 2 
			if report-blk [
				append report-blk blk
			]
			
			; we store all reports in the unit.
			append test-report blk
			result
		]
				
		vout
		test-passed?: result
	]
	



	;-----------------
	;-    assert()
	;
	; execute and verify a unit test.
	;-----------------
	assert: func [
		tests [block!] "A list of tests you want to perform."
		/report report-blk "returns a report on all tests"
		/stop "stop at first failure"
		/local result
	][
		vin [{!unit/assert()}]
		
		; run the request 
		execute
		
		; then run a series of tests on the responce.
		result: apply :pass? [ tests report report-blk stop ]
		vout
		
		result
	]
	
	


	
	;-  
	;-    REPORTING METHODS
	
	;-----------------
	;-    report-as-is()
	;
	; just dump all non binary information about this unit
	;-----------------
	report-as-is: func [
	][
		vin [{report-as-is()}]
		vprint [ "port-spec/scheme: " port-spec/scheme]
		vprint [ "port-spec/host: " port-spec/host]
		vprint [ "port-spec/port-id: " port-spec/port-id]
		vprint [ "port-spec/uri: "  port-spec/uri]
		vprint [ "port-spec/user: " port-spec/user]
		vprint [ "port-spec/pass: " port-spec/pass]
		v?? http-method
		v?? http-version
		v?? request
		v?? response
		v?? parameters
		vout
	]
	
	
	
	
]


;-  
;- FUNCTIONS


;-----------------
;-    http-test()
;
; a simple entry point for a complete unit test. returns the unit which was executed.  
; it can then be used to probe every part of the test cycle.
;-----------------
http-test: func [
	url [url!]
	test [block!]
	/HEAD "do a HEAD request"
	/POST data "do a POST request"
	/continue [object!] "Any required multi-part test data will be retrieved from the response in this previous unit."
	/quiet "don't print out result and report"
	/report report-blk [block!]
	/with headers [object! block!] "Give a set of headers to use in this request. These overide any automatic handling in the engine."
	/local unit
][
	vin [{test()}]
	unit: make !unit [
		; create all unit test internal data
		init
		
		; set the following url to your testing site, usually, we setup this specific url
		; within the hosts file, so it points to localhost
		; and use a vhost on the web-server which handles it.
		;
		; note that user:password and :port-number are all supported within the url, if required
		; by tests themselves.
		set-url url
		
	]
	
	if HEAD [
		unit/http-method: 'HEAD
	]

	if POST [
		unit/http-method: 'POST
	]
	
	if with [
		; save the given headers for use as overides in the request
		unit/request/user-header: make context [] headers
	]
	
	apply get in unit 'assert [ test report report-blk false ]
	
	unless quiet [
		vprint/always [
			"^/^/TEST REPORT: " mold/all
			unit/test-report
		]
		vprint/always "^/^/----------------------------------"
		vprint/always ["ALL TESTS PASSED?: " unit/test-passed?]
		vprint/always "----------------------------------"
	]
	
	vout
	unit
]



;-----------------
;-    http-get()
;-----------------
http-get: func [
	url [url!]
][
	vin [{http-get()}]
	unit: make !unit [
		; create all unit test internal data
		init
		
		; set the following url to your testing site, usually, we setup this specific url
		; within the hosts file, so it points to localhost
		; and use a vhost on the web-server which handles it.
		;
		; note that user:password and :port-number are all supported within the url, if required
		; by tests themselves.
		set-url url
		
		execute
	]
	
	vout
	unit
]



;-----------------
;-    http-head()
;-----------------
http-head: func [
	url [url!]
][
	vin [{http-head()}]
	unit: make !unit [
		; create all unit test internal data
		init
		
		; set the following url to your testing site, usually, we setup this specific url
		; within the hosts file, so it points to localhost
		; and use a vhost on the web-server which handles it.
		;
		; note that user:password and :port-number are all supported within the url, if required
		; by tests themselves.
		set-url url
		
		execute
	]
	
	vout
	unit
]




