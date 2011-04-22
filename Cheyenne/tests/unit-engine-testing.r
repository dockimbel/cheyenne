REBOL [
	file: %unit-engine-testing.r
	author: "Maxim Olivier-Adlhoch"
	date: 2010-07-08
	version: 0.5.1
	title: "Script which tests the unit-engine itself.  Also serves as a reference for engine usage."
	notes: [
		"-requires rebol 2.7.7"
	]
	
	license-type: 'MIT
	license:      {Copyright © 2010 Maxim Olivier-Adlhoch.

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



;----
; eventually allow a config file to setup the unit testing engine
; do %config.r

;----
; load all modules required to run unit tests
do %libs/unit.r

;----
; this enables verbose tracing of all activity using a flexible stack-based printout mechanism
; we can optionally add log-file capabilities directly to the vprint system
von


;----
; create an http unit testing object, which wraps all functions and data
; required to run a single http request/response run.
;
; as the project advances, different !unit subclasses will be created which
; manage specific domains of testing.
;
; the core !unit object is sufficient to test all http protocol issues.
;----
unit: make !unit [
	; create all unit test internal data
	init
	
	; set the following url to your testing site, usually, we setup this specific url
	; within the hosts file, so it points to localhost
	; and use a vhost on the web-server which handles it.
	;
	; note that user:password and :port-number are all supported within the url, if required
	; by tests themselves.
	set-url http://localhost:81
	
	; do the http request for this unit
	execute
]


;----
; perform tests on the server response from that unit.
;
; /report allows us to accumulate all test results in a simple block
;
test-passed?: unit/pass?/report [
	;----
	; TEST: 'CHECK-HEADER
	;
	; this test operation compares the header for expected values
	check-header [
		Content-Length: "200"
		Content-Type: "text/html"
	]
	
	;----
	; TEST: 'DO
	;
	; this test operation runs arbitrary REBOL code.
	; the return value of the block is used to qualify test as passed or failed.
	;
	; ONLY TRUE results will pass the test, anything else is considered a failure.
	; the returned value is supplied to the report, so you can get more details on failures.
	do [
		all [
			unit/response/status-code = 200
			unit/response/header/Content-Length = "200"
			true
		]
	]
] report: []


;----
; did the actual http request go thru successfully?
vprobe unit/response/success?


;----
; what is the status-line returned by server
vprobe unit/response/status-line


;----
; what content was returned in the http response
vprobe to-string unit/response/header


;----
; did the unit pass all tests operations?
v?? test-passed?


;----
; print out the accumulated report of all test operations.
v?? report


;----
; print out the full unit test report.
unit/report-as-is

ask "^/-------^/press enter to close console"