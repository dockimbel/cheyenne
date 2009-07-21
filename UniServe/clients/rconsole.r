REBOL []

do %../uni-engine.r

install-protocol [
	name: 'RConsole
	port-id: 9801

	stop-at: to-string to-char 255
	
	prompt: has [cmd][
		cmd: trim ask "Server> "
		if find ["q" "quit" "exit"] cmd [quit]
		write-server append cmd stop-at
	]
	
	on-received: func [data][
		remove back tail data
		if not empty? data [prin to-string data]
		prompt
	]
	events: []
]

uniserve/boot/no-wait/with [protocols [RConsole]]
open-port rconsole://localhost []
wait []
