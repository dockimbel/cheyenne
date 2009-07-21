REBOL []

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
	
	getpid: make routine! [return: [integer!]] libc "getpid"

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