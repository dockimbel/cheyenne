REBOL [
	file: %cheyenne-HEADERS-tests_Accept-Langage.r
	author: "Maxim Olivier-Adlhoch"
	date: 2011-04-22
	version: 0.1.0
	title: "Tests the integrated language support of cheyenne."
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
vprint/always "| Request/header/Accept-Language tests  |"
vprint/always "|                                       |"
vprint/always "+---------------------------------------+"


;--------------
; test language header support
;--------------
http-test/with "/lang.rsp in english?" %/lang.rsp [	do ["Hello" = response/content ] ]   [ Accept-Language: "en;en-US"]

http-test/with "/lang.rsp in french?" %/lang.rsp  [	do ["Bonjour" = response/content] ]  [ Accept-Language: "fr;fr-CA"]

http-test "/lang.rsp in english **by default**   ?" %/lang.rsp [ do ["Hello" = response/content]]
