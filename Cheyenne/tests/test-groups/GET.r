REBOL [
	file: %cheyenne-GET-tests.r
	author: "Maxim Olivier-Adlhoch"
	date: 2011-04-22
	version: 0.2.0
	title: "Tests the GET method of cheyenne."
	notes: [
		"requires rebol 2.7.7 or later"
		"must be launched from another script which loads the unit testing framework"
	]
	
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


vprint/always ""
vprint/always "+---------------------------------------+"
vprint/always "|                                       |"
vprint/always "|              GET  tests               |"
vprint/always "|                                       |"
vprint/always "+---------------------------------------+"


;---------------------------------------------------
; this is a default test setup which should work for all
; successful GETs of the 200bytes.html file in whatever
; folder it is.
;---------------------------------------------------
default-tests: dt: [
	;---
	; verifies the status-line information
	status 200
	http-version 'same?
	
	;---
	; verifies expected header values
	check-header [
		Content-Length: "200"
		Content-Type: "text/html"
	]
	
	;---
	; returns true if the data is a valid internet date
	is-http-date? [response/header/date]
	is-http-date? [response/header/Last-Modified]
	
	;---
	; returns true if response finishes within time limit
	response-time 0:0:0.002
]

http-test "GET /" %/ dt
http-test "GET /200bytes.html" %/200bytes.html dt
http-test "GET /subdir/" %/subdir/ dt
http-test "GET /subdir .................. (test folder Redirection!)" %/subdir [status 301 Location: "/subdir/" ] ; do [probe response/header true]]
http-test "GET /subdir/200bytes.html" %/subdir/200bytes.html dt
http-test "GET /subdir/200bytes.txt ..... (test Content-Type: )" %/subdir/200bytes.txt [
	check-header [
		Content-Length: "200"
		Content-Type: "text/plain"
	]
]

http-test "GET /invalid.html ............ (verify expected 404 error return.)" %/invalid.html [status 404]

;ask ""
