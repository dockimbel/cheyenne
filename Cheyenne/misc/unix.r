REBOL []

all [
	any [
		exists? libc: %libc.so.6
		exists? libc: %/lib32/libc.so.6
		exists? libc: %/lib/libc.so.6
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
]
set 'launch-app func [cmd [string!] /local ret][
	ret: call/info cmd
	reduce ['OK ret/id]
]
set 'kill-app func [pid][
	call join "kill " pid
]
set 'process-id? does [getpid]