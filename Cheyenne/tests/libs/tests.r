REBOL [
	file: %tests.r
	author: "Maxim Olivier-Adlhoch"
	date: 2010-07-08
	version: 0.5.1
	title: "Testing operations for use in cheyenne test-suite."
	
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


unit-tests: []

; we expect this lib to already be loaded before running any command here.
; do %mezz.r


append unit-tests reduce [
	;----
	;- TEST: 'DO
	;
	; low level testing operation
	;
	; this test operation runs arbitrary REBOL source.
	;
	; the source block is bound to the unit prior to execution, so it
	; may refer to any value within the unit by path notation starting at unit/...
	;
	; the return value of the block is used to qualify test as passed or failed.
	;
	; any error is returned, disarmed so it can be used to debug testing problems.
	;
	; ONLY TRUE results will pass the test, anything else is considered a failure.
	; the returned value is supplied to the report, so you can get more details on failures.
	'do func [
		unit [object!] 
		params [block! none!] 
		report [block! none!]
		/local result error
	][
		params: bind copy/deep params unit
	
		if error? error: try [
			result: do params
		][
			result: disarm error
		]
		
		
		if report [
			append report reduce ['do result]
		]
		result
	]
	
	
	;----
	;- TEST: 'CHECK-HEADER
	;
	; this test operation compares the header for expected values
	;
	; params is converted to an object, so it may actually contain expression values, not just literals.
	;
	'check-header func [
		unit [object!] 
		params [block! none!] 
		report [block! none!]
		/local result error word success? results value
	][
		if error? error: try [
			if report [
				results: copy []
			]
			params: context params
			result: true
			foreach [word] words-of params [
				success?: params/:word = value: get in unit/response/header word
				if report [
					; if success? failed, we put the value instead of success?
					either success? [
						append results reduce [word true]
					][
						append results reduce [word value]
					]
				]

				; until success? is false
				if result [
					result: success?
				]
			]
		][
			result: disarm error
		]
		
		if report [
			new-line/skip results true 2 
			append report reduce ['check-header results]
		]
		result
	]
	
	;----
	;- TEST: 'IS-HTTP-DATE?
	;
	; here we expect the date to be http 1.1 encoded using the strict grammar rules defined below in the RFC
	;
	; 
	'is-http-date? func [
		unit [object!] 
		params [block! none!]  "A none params always returns true (a stand-in empty test should not invalidate the test)."
		report [block! none!]
		/local result d date-string
	][
		; allow the params to refer to any value which may be contained in the tested unit.
		params: bind/copy params unit
		date-string: do params
		d: parse-http-date date-string
		
		result: object? d
		
		
		if report [
			either d [
				append report reduce ['is-http-date? true]
			][
				append report reduce ['is-http-date? date-string]
			]
		]
		?? result
		result
	]
]

