REBOL []

install-HTTPd-extension [
	name: 'mod-socket
	
	order: [
		socket-connect		normal
		socket-message		normal
		socket-disconnect	normal
	]
	
	apps: make block! 8
	mappings: make block! 8
	random/seed now/time/precise
	
	app-class: context [
		;-- private words
		__name: __ctx: __id: none
		
		;-- public API
		timer?: no
		session: on-connect: on-message: on-disconnect: on-timer: clients: none
		
		set-timer: func [delay [time! none!]][
			timer?: either delay [
				scheduler/add-job/every/name [on-timer] delay __id
				yes
			][
				scheduler/delete __id
				no
			]
		]
		
		send: func [data [string!] /with port [port!]][
			service/ws-send-response/direct/with data port
		]
		
		disconnect: func [/with port [port!]][
			either with [
				service/close-client/with port
			][
				service/close-client
			]
		]
		
		do-task: func [data [string!] /on-done handler [function! block!]][
			__ctx/in/content: data
			service/mod-list/mod-rsp/make-response __ctx
			__ctx: none
		]
	]
	
	make-unique-id: has [id][
		until [
			id: random 9999
			any [
				all [
					not empty? apps
					foreach [name app] apps [if app/__id = id [break/return false] true]
				]
				true
			]
		]
		to word! join "SA" id
	]
	
	set 'install-socket-app func [spec [block!] /local new][
		new: make make app-class [__id: make-unique-id clients: make hash! 100] spec
		repend apps [new/name new]
	]
	
	fire-event: func [req event [word!] /arg data /local err app current][
		app: req/socket-app
		app/__ctx: req
		current: service/client
		service/client: req/socket-port
		unless data [data: service/client]
		if error? set/any 'err try [app/:event data][
			log/error rejoin [event " call failed with error: " mold disarm err]
		]
		service/client: current
		app/__ctx: none
	]
	
	socket-connect: func [req][
		req/socket-app: select mappings req/in/url
		append req/socket-app/clients service/client
		fire-event req 'on-connect
	]
	
	socket-message: func [req][
		fire-event/arg req 'on-message as-string req/in/content
	]
	
	socket-disconnect: func [req /local app][
		fire-event req 'on-disconnect
		remove find req/socket-app/clients req/socket-port
	]
	
	words: [
		;--- Define the URL to web socket application name mapping
		socket-app: [string!] [word!] in main do [		
			use [root file][
				either root: select scope 'root-dir [
					either exists? file: rejoin [root %/ws-apps/ args/2 ".r"][
						do file
						repend mappings [args/1 last apps]
					][
						log/error ["can't access file " file]
					]
				][
					log/error ["root-dir is missing, can't load socket-app " mold args/2]
				]
			]
		]
	]
]
