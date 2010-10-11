REBOL []

all [
	any [
		exists? libc: %libc.so.6
		exists? libc: %/lib32/libc.so.6
		exists? libc: %/lib/libc.so.6
		exists? libc: %/System/Index/lib/libc.so.6  ; GoboLinux package
		exists? libc: %/system/index/framework/libraries/libc.so.6  ; Syllable
		exists? libc: %/lib/libc.so.5
	]
	libc: load/library libc
	_setenv: make routine! [
		name		[string!]
		value		[string!]
		overwrite	[integer!]
		return: 	[integer!]
	] libc "setenv"
	
	getpid: make routine! [return: [integer!]] libc "getpid"
	
	set 'set-env func [name [string!] value [string!]][
		_setenv name value 1
	]
	set 'setuid make routine! [uid [integer!] return: [integer!]] libc "setuid"
	set 'setgid make routine! [gid [integer!] return: [integer!]] libc "setgid"
	
	set 'chown make routine! [
		path 	[string!]
		owner 	[integer!]
		group 	[integer!]
		return: [integer!]
	] libc "chown"
]
set 'launch-app func [cmd [string!] /local ret][
	ret: call/info cmd
	reduce ['OK ret/id]
]
set 'kill-app func [pid][
	call join "kill " pid
]
set 'process-id? does [getpid]

tcp-states: [
	ESTABLISHED
	SYN_SENT
	SYN_RECEIVED
	FIN_WAIT_1
	FIN_WAIT_2
	TIME_WAIT
	CLOSED
	CLOSE_WAIT
	LAST_ACK
	LISTEN
	CLOSING
]

set 'list-listen-ports has [p out value state][
	p: open/read/lines %/proc/net/tcp
	out: make block! length? p
	p: next p					;-- skip column names line
	until [
		parse/all first p [
			thru ": " thru #":" copy value to #" "
			thru #":" thru #" " copy state to #" "
		]
		state: pick tcp-states to integer! debase/base state 16
		if all [
			state = 'LISTEN
			not find out value: to integer! debase/base value 16
		][
			append out value
		]
		tail? p: next p
	]
	close p
	sort out
]
