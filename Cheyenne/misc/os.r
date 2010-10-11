REBOL []

OS-ctx: make log-class [
	name: 'OS
	verbose: 0
	
	sys: none
	
	either find system/components 'library [
		sys: make log-class [name: 'OS-API verbose: 2]
		sys: make sys load-cache switch system/version/4 [
			2 [%misc/macosx.r]
			3 [%misc/win32.r]
			4 [%misc/unix.r]
		]
	][	; === /Library component not available, minimal setup ===
	
		set 'launch-app func [cmd [string!] /local ret][
			ret: call/info cmd
			reduce ['OK ret/id]
		]
		set 'kill-app func [pid][
			either system/version/4 = 3 [
				log/warn "cannot kill external app"
			][
				call join "kill " pid
			]
		]
		set [set-env process-id? NT-Service? list-listen-ports] none
		set [setuid setgid chown] 0		;-- 0 is the OK result
	]
]

