REBOL [
	Title: "Remote Console service"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Date: 27/05/2007
	Version: 1.1.0
	Purpose: "Provide a remote console service allowing remote REBOL expressions evaluation"
]

netstat: has [pad][
	pad: func [v n][
		head insert/dup tail v: form v #" " n - length? v
	]
	print ["wait-list length:" length? system/ports/wait-list newline]
	print "Scheme   Port   Client-IP     Service          Expire-time"
	print "----------------------------------------------------------"
	foreach p system/ports/wait-list [
		print [
			pad p/scheme 8
			pad p/port-id 6
			pad p/remote-ip 15
			pad attempt [p/locals/handler/name] 16
			pad attempt [p/locals/expire] 26
		]
	]
]

install-service [
	name: 'RConsole
	port-id: 9801
	verbose: 0
	out: make string! 100000
	
	stop-at: to-string to-char 255

	emit: func [value][write-client append value stop-at]
	
	print-funcs: reduce [
		func [value][	
			append out form reduce :value
			append out newline
			unset 'value
		]
		func [value][
			append out form reduce :value
			unset 'value
		]
		func [value][
			append out mold :value
			append out newline
			:value
		]
	]

	;--- Function borrowed from Gabriele Santilli
	form-error: func [errobj [object!] /all /local errtype text][
		errtype: get in system/error get in errobj 'type
		text: get in errtype get in errobj 'id
		if block? text [text: reform bind/copy text in errobj 'self]
		either all [
			rejoin [
				"** " get in errtype 'type ": " text newline
				either get in errobj 'where [join "** Where: " [mold get in errobj 'where newline]] [""]
				either get in errobj 'near [join "** Near: " [mold/only get in errobj 'near newline]] [""]
			]
		][
			text
		]
	]

	exec: func [data /local saved result][
		saved: reduce [:print :prin :probe]
		set [print prin probe] print-funcs
		error? set/any 'result try load/all to-string data
		set [print prin probe] saved
		if any [unset? 'result not value? 'result][
			emit out
			exit
		]
		either error? :result [
			append out form-error/all disarm :result
		][
			either any [
				object? :result
				port? :result
			][
				append out newline
			][
				append out join "== " mold :result
				append out newline
			]
		]		
		emit out
	]
	
	on-new-client: does [
		if not find [127.0.0.1] client/remote-ip [close-client]
		emit copy "Connected to UniServe^/Remote Console Service^/"
	]
	
	on-received: func [data][
		remove back tail data
		clear out
		exec data
	]
]