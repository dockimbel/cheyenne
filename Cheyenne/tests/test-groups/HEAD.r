REBOL [
	file: %cheyenne-HEAD-tests.r
	author: "Maxim Olivier-Adlhoch"
	date: 2011-04-22
	version: 0.2.0
	title: "Tests the HEAD method of cheyenne."
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


vprint/always "^/^/"
vprint/always "+---------------------------------------+"
vprint/always "|                                       |"
vprint/always "|             HEAD  tests               |"
vprint/always "|                                       |"
vprint/always "+---------------------------------------+"

;--------------
; just get a page, don't test it.
;--------------
unit-a: http-get %/200bytes.html

;--------------
; get a page header, test it and compare it to the get result
;--------------
http-test/head "HEAD /200bytes.html ...... (tests header is *exactly* the same as GET  &  no content)" %/200bytes.html [
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
	; returns true if our header is equivalent to given one
	same-header?  [unit-a]
	
	do [
		; uncomment for proof of header equality.
		;probe unit-a/response/header
		;probe response/header
		(none? response/content)
	]
	
	;---
	; returns true if response finishes within time limit
	response-time 0:0:0.002
]

