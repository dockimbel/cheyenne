REBOL [
	file: %cheyenne-http-tests.r
	author: "Maxim Olivier-Adlhoch"
	date: 2011-02-05
	version: 0.1.0
	title: "Script which tests cheyenne's http handling."
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


do %libs/unit.r

print "======================================================================================="
print "   HTTP 'GET tests:"
print "======================================================================================="
print ""
print "simple get page and verify header"
print "---------------------------------"
page: http://localhost:81

unit: http-test/HEAD page [
	check-header [
		Content-Length: "386"
		Content-Type: "text/html"
	]
	is-http-date? [probe response/header response/header/date]
	is-http-date? [probe response/header response/header/server]
]

print ["success?: " unit/test-passed?]

von
;unit/report-as-is

ask ""