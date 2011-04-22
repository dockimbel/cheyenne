REBOL [
	file: %cheyenne-http-tests.r
	author: "Maxim Olivier-Adlhoch"
	date: 2011-04-22
	version: 0.1.1
	title: "Springboard script which calls all other http testing scritps in this suite."
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


;----------------------------------
; Setup unit test logging.
;----------------------------------
; note, the log file automatically adapts for cheyenne's version.
cheyenne-version: get-script-version %../cheyenne.r
log-file: clean-path rejoin [ %test-logs/ 'unit-test-vlog- cheyenne-version ".txt"]
unless exists? %test-logs/ [make-dir %test-logs/]
vlog/only log-file
vlogclear ; clear the previous log, if it has the same name.

;----------------------------------
; Setup unit test environment.
;----------------------------------
set-default-host/port 'localhost 80 ; used by %unit.r library stub functions like http-test(), http-get(), http-head(), etc.



vprint/always "======================================================================================="
vprint/always ""
vprint/always ["    Unit testing for Cheyenne v" cheyenne-version "  performed: " now/date "/" now/time]
vprint/always ""
vprint/always "======================================================================================="

; make sure we don't have console verbosity enabled during tests (this is very extensive)
voff


;von
; launch test groups.
do %test-groups/GET.r
do %test-groups/HEAD.r
do %test-groups/HEADERS_Accept-Langage.r



vprint/always "^/^/======================================================================================="
either all-tests-passed? [
	vprint/always  [ "ALL  (" test-count ")  TESTS COMPLETED, SUCCESS"]
][
	vprint/always "SOME TESTS FAILED"
	vprint/always ""
	vprint/always ["  total tests:   " test-count]
	vprint/always ["  failed:        " failed-test-count]
	vprint/always ["  success ratio: " round/to ((test-count - failed-test-count) / test-count * 100) 0.01 "%"]
]
print ""
print "Press enter to close window"
vprint/always "======================================================================================="

ask ""
