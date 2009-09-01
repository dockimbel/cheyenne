REBOL []

install-HTTPd-extension [
	name: 'mod-extapp
	verbose: 0
	
	extapp!: context [name: instances: jobs: balancing: specs: none]
	app!:    context [pid: ports: none]

	templates: make block! 1 ; [[spec] ...]
	actives: make block! 1 ; [name extapp! ...]
	;-- extapp/jobs specs: [timestamp req client state ...]
	
	round-robin: func [list /local idx][
		idx: [-1]
		pick list 1 + idx/1: remainder idx/1 + 1 length? list
	]

	launch-servers: has [cmd chan ret new n v delay][
		foreach spec templates [
			parse spec [
				some [
					'environment into [
						any [set n skip set v skip (set-env form n form v)]
					]
					| 'command set cmd string!
					| 'channels set chan integer!
					| skip
				]
			]
			new: make extapp! [
				name: spec/name
				jobs: make block! 8
				instances: make block! 1
				get-balanced: either chan [:round-robin][:first]
				specs: spec
			]
			either cmd [
				ret: launch-app cmd
				either ret/1 = 'ok [
					new/instances: all [
						cmd ret/1 = 'ok
						reduce [make app! [pid: ret/2]]
					]
					if number? delay: select spec 'delay [
						scheduler/stop
						wait delay
						scheduler/start
					]
				][
					log/error reform [
						"cannot launch :" cmd newline 
						"OS message:" trim form ret/2
					]
				]
			][
				new/instances: reduce [make app! []]
			]
			repend actives [spec/name new]
		]
	]
	
	kill-servers: does [
		foreach [name extapp] actives [
			foreach app extapp/instances [
				if app/pid [
					kill-app app/pid
					if verbose > 0 [log/info reform [name "killed"]]
				]
			]
		]
	]
	
	set 'extapp-register func [
		scheme [word!]
		evt [block!]
		/with defs [block!]
		/local out url delay app
	][
		out: make block! 1
		foreach [name extapp] actives [	
			if all [
				url: select extapp/specs 'url
				scheme = get in parse-url url 'scheme
			][
				foreach app extapp/instances [
					ctx: service/client				
					defs: repend any [defs make block! 2][
						to-set-word 'job-queue none
						to-set-word 'connect-retry 3
						to-set-word 'stats none
					]
					loop any [select extapp/specs 'channels 1][
						port: open-port/with select extapp/specs 'url evt defs
						port/job-queue: make block! 64
						port/stats: copy [0 0]			; [req-nb out-size]
						service/set-peer ctx
						either app/ports [
							append app/ports port
						][
							app/ports: reduce [port]
						]
					]
				]
				append out name
			]
		]
		out
	]
	
	set 'extapp-pop-job func [list /local extapp jobs sel][
		foreach name list [
			if all [
				extapp: select actives name
				not empty? extapp/jobs
			][
				jobs: extapp/jobs
				sel: none			
				while [not empty? jobs][			
					either jobs/1/4 = 'pending [
						either closed-port? jobs/1/3 [					
							remove jobs
						][
							if not sel [sel: jobs/1]
							jobs: next jobs
						]
					][
						return none
					]
				]
				if sel [return sel]
			]
		]
		none
	]
	
	set 'extapp-clear-job func [job id][
		extapp: select actives id
;print ["jobs:" length?	extapp/jobs]	
		remove find/only extapp/jobs job
;print ["jobs:" length?	extapp/jobs]		
	]

	set 'extapp-make-job func [
		req [object!]
		/local extapp app job port
	][
		job: reduce [
			now/precise
			req
			service/client
			'pending
		]
		all [
			any [
				extapp: select actives req/handler
				all [log/error rejoin ["extapp" req/handler "not found"] false]
			]
			all [
				insert/only tail extapp/jobs job
				extapp/instances
				not empty? extapp/instances ;=> abort, launch extapp
				app: first extapp/instances
			]
			all [
				app/ports
				not empty? app/ports
				port: extapp/get-balanced app/ports
				all [
					closed-port? port		;=> abort, reopen
					port: reopen-port port
					false
				]
				not object? port/locals		; port is opening and is not ready yet
				port: none
			]
		]
		reduce [port job]
	]

	on-started: func [svc][
		launch-servers
	]
	
	on-reload: func [svc][
		kill-servers
	]
	
	on-quit: func [svc][
		kill-servers
	]
	
	words: [
		extern-app: [block!] in globals do [
			append/only templates args/1
		]
	]
]
	