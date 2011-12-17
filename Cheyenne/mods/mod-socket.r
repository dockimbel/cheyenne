REBOL []

install-HTTPd-extension [
	name: 'mod-socket
	verbose: 0
		
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
		__name: __ctx: __id: __file: __last-ts: none
		
		;-- public API
		timer?: no
		rsp-session: on-connect: on-message: on-disconnect: on-timer: clients: none
		
		set-timer: func [delay [time! none!]][
			either delay [
				scheduler/add-job/every/name compose [fire-event (__ctx) 'on-timer] delay __id				
			][
				scheduler/delete __id
			]
			timer?: to logic! delay
		]
		
		send: func [port [port!] data [string!]][
			service/ws-send-response/direct/with data port
		]
		
		disconnect: func [/with port [port!]][
			either with [
				service/close-client/with port
			][
				service/close-client
			]
		]
		
		do-task: func [data [string!] /on-done handler [function! block!]][ ;-- handler: func [client data][...]
			__ctx/in/content: data
			if on-done [append/only __ctx/tasks :handler]		;-- store handler for deferred action
			service/mod-list/mod-rsp/make-response __ctx		;-- trigger a bg job through RSP pipe
			__ctx: none
		]
	]
	
	make-unique-id: has [id][
		until [
			id: random 9999
			either empty? apps [true][
				foreach [name app] apps [if app/__id = id [break/return false] true]
			]
		]
		to word! join "SA" id
	]
	
	set 'install-socket-app func [spec [block!] /local new][
		new: make make app-class [__id: make-unique-id clients: make hash! 100] spec
		repend apps [new/name new]
		new
	]
	
	get-app: func [req /local app ts file][
		if all [
			app: select mappings req/in/url
			app/__last-ts <> ts: modified? file: app/__file 
		][
			app: do file
			app/__last-ts: ts
			app/__file: file
			change next find mappings req/in/url app
			remove/part find apps app/__name 2					;-- remove the old app version
			if verbose > 0 [log/info ["socket-app " mold app/__name " updated"]]
		]
		app
	]
	
	fire-event: func [
		req
		action [word! function! block!]
		/arg data
		/local err app current
	][
		app: req/socket-app
		app/__ctx: req
		app/rsp-session: req/session
		current: service/client
		service/client: req/socket-port		
		if error? set/any 'err try pick [
			[app/:action req/socket-port data]				;-- event action
			[do :action req/socket-port data]				;-- function! or block! action
		] word? :action [
			log/error rejoin [mold :action " call failed with error: " mold disarm err]
		]
		service/client: current
		app/__ctx: app/rsp-session: none
	]
	
	socket-connect: func [req][
		if req/socket-app: get-app req [
			append req/socket-app/clients service/client
			req/session: service/mod-list/mod-rsp/sessions/exists? req
			req/tasks: make block! 10
			fire-event req 'on-connect
		]
		true
	]
	
	socket-message: func [req][
		fire-event/arg req 'on-message as-string req/in/content
		true
	]
	
	socket-disconnect: func [req /local app][
		remove find req/socket-app/clients req/socket-port
		fire-event req 'on-disconnect
		true
	]
	
	on-task-done: func [req /local action][					;-- event generated from mod-rsp
		if verbose > 0 [log/info "calling on-task-done"]	
		if action: pick req/tasks 1 [
			remove req/tasks
			fire-event/arg req :action req/out/content
		]
	]
	
	words: [
		;--- Define the URL to web socket application name mapping
		socket-app: [string!] [word!] in main do [		
			use [root file app][
				either root: select scope 'root-dir [
					either exists? file: rejoin [root %/ws-apps/ args/2 ".r"][
						app: do file
						app/__file: file
						app/__last-ts: modified? file
						repend mappings [args/1 app]
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
