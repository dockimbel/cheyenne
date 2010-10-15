REBOL []

make-null-string!: func [len [integer!]][
	head insert/dup make string! len null len
]

all [
	libc: load/library %libc.dylib
	_setenv: make routine! [
		name		[string!]
		value		[string!]
		overwrite	[integer!]
		return: 	[integer!]
	] libc "setenv"
	set 'set-env func [name [string!] value [string!]][
		_setenv name value 1
	]
	
	get-pid: make routine! [return: [integer!]] libc "getpid"

	set 'set-uid make routine! [uid [integer!] return: [integer!]] libc "setuid"
	set 'set-gid make routine! [gid [integer!] return: [integer!]] libc "setgid"
	
	set 'chown make routine! [
		path 	[string!]
		owner 	[integer!]
		group 	[integer!]
		return: [integer!]
	] libc "chown"	
	
	set 'kill make routine! [
		pid 	[integer!]
		sig 	[integer!]
		return: [integer!]
	] libc "kill"
]

set 'launch-app func [cmd [string!] /local ret][
	ret: call/info cmd
	reduce ['OK ret/id]
]
set 'kill-app func [pid][
	kill pid 15			; SIGTERM
]
set 'process-id? does [get-pid]

set 'list-listen-ports has [buffer out value][
	buffer: make string! 10000
	call/output "netstat -f inet -p tcp -na" buffer
	out: make block! 10
	parse/all buffer [
		2 [thru newline]		;-- skip header lines
		any [
			thru "*." [
				#"*" | copy value to #" " (
					if not find out value: to-integer value [append out value]
				)
			]
		]
	]
	sort out
]
