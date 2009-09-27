REBOL []

;--- TBD: trap errors !

; TBD: replace alert function by a call to MessageBox win32 API (would work with both Core&View)
alert: func [msg /local svs][
	svs: system/view/screen-face
	svs/pane: reduce [
		make face [
			offset: (system/view/screen-face/size - 200x50) / 2
			size: 400x100
			pane: make face [
				size: 380x80
				offset: 0x24
				text: msg
			]
		]
	]
	show svs
	open-events
	wait []
	clear svs/pane
	show svs
]

make log-class [
	name: 'system
	verbose: 2

	sys: system-awake: modes: none
	
	events: normal-events: [
		run-as	[
			if system/options/home = OS-get-dir 'desktop [
				append cheyenne/sub-args " -fromdesk"
			]
			either install-NT-service [
				uniserve/services/httpd/on-quit
				cheyenne/on-quit
				uniserve/control/shutdown
				control-service/start
				launch/quit cheyenne/sub-args
			][
				alert "ERROR : installing a service requires Administrator rights!"
			]
		]
		reload  [
			uniserve/services/httpd/on-reload
		]
		reset [
			uniserve/services/task-master/on-reset
		]
		quit [
			uniserve/services/httpd/on-quit
			cheyenne/on-quit
			close sys
			uniserve/flag-stop: on
			quit
		]
	]
	
	remote-events: [
		run-as	[
			if NT-service-running? [control-service/stop]
			uninstall-NT-service
			wait 1
			launch/quit cheyenne/sub-args
		]
		reload  [
			write/direct/no-wait udp://127.0.0.1:10000 "R"
		]
		reset  [
			write/direct/no-wait udp://127.0.0.1:10000 "W"
		]
		quit [
			close sys
			throw 'quit
		]
	]
	
	remote-mode: [
		tray: [
			add main [
				help: "Cheyenne is running"
				menu: [
				;	about:  "About..."
					run-as: "Run as user application"
					bar
					reload: "Reload Config"
					reset: "Reset Workers"
					bar
					quit: 	"Quit"
				]
			]
		]
	]
	
	set 'set-tray-remote-events does [
		events: remote-events
		set-modes sys remote-mode
	]
	
	set 'set-tray-help-msg func [msg [string!]][
		modes/(to-set-word 'tray)/main/2: msg
		remote-mode/(to-set-word 'tray)/main/2: msg
	]
	
	do-action: func [evt][
		if verbose > 0 [log/info ["event received: " mold evt]]
		switch evt events
	]

	either system/version/4 = 3 [
;--- Windows platforms	
		system-awake: func [port /local evt][
			if all [
				evt: pick port 1
				evt/1 = 'tray
				evt/3 = 'menu
			][
				do-action evt/4
			]
			false
		]
		modes: [
			tray: [
				add main [
					help: "Cheyenne is running"
					menu: [
					;	about:  "About..."
						run-as: "Run as service"
						bar
						reload: "Reload Config"
						reset: "Reset Workers"
						bar
						quit: 	"Quit"
					]
				]
			]
		]
	][
;--- All others platforms	
		system-awake: func [port /local evt][
			evt: pick port 1
			if verbose > 1 [
				log/info ["raw event:" mold evt]
			]
			if evt: select evt 'signal [
				do-action select [
					sighup	 reload
					sigusr1	 reset
					sigint	 quit
					sigquit	 quit
					sigterm	 quit
				] evt
			]
			false
		]
		modes: [
			signal: [sighup sigusr1 sigint sigquit sigterm]
		]
	]

	set 'open-system-events does [
		sys: system/ports/system: open [scheme: 'system]
		append system/ports/wait-list sys
		sys/awake: :system-awake
		set-modes sys modes
	]
]
