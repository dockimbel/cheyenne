REBOL [
	file: %cheyenne-http-tests.r
	author: "Maxim Olivier-Adlhoch"
	date: 2011-04-24
	version: 0.1.1
	title: "Script which tests cheyenne's low-level http handling."
	notes: [
		"requires rebol 2.7.7 or later"
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


do %libs/unit.r

print "======================================================================================="
print "   HTTP  tests:"
print "======================================================================================="
print ""
page: http://localhost:81/200bytes.html

;--------------
; just get a page, don't test it.
;--------------
unit-a: http-get page

;--------------
; get a page header, test it and compare it to the get result
;--------------
http-test/head page [
	;---
	; compares header values
	check-header [
		Content-Length: "200"
		Content-Type: "text/html"
	]
	
	do [
		probe request/header
		probe response/header
		true
	]
	;---
	; returns true if the data is a valid internet date
	is-http-date? [response/header/date]
	is-http-date? [response/header/Last-Modified]
	
	;---
	; returns true if our header is equivalent to given one
	same-header?  [unit-a]
	
	;---
	; returns true if response finishes within time limit
	response-time 0:0:0.002
] [ Accept-Language: "fr;fr-ca"]


;--------------
; test language header support
;--------------
http-test/with http://localhost:81/lang.rsp [
	do [
		"Bonjour" = response/content
		true
	]
][
	Accept-Language: "fr;fr-CA"
]


ask ""
