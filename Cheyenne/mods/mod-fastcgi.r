REBOL []

install-HTTPd-extension [
	name: 'mod-fastcgi 
	
	order: [
		url-to-filename	first
		set-mime-type	normal
		access-check	normal
		make-response	normal
		logging			last
	]
		
	dot: #"."
	seq-id: 1
	register-list: []	
	
	on-started: func [svc /local s ctx][
		register-list: extapp-register/with 'fastcgi [
			on-response: func [port data err /local jobs ctx req][
				if series? data [port/stats/2: port/stats/2 + length? data]
				if err [log/warn err]
				jobs: find port/job-queue port/id
				ctx: service/client					; save current client port context
				service/set-peer jobs/2/3
				service/on-task-done data req: jobs/2/2				
				extapp-clear-job jobs/2 req/handler
				remove/part jobs 2
				service/set-peer ctx				; restore saved client port context
				port/locals/handler/on-ready port 
			]
			on-error: func [data][log/error length? mold data]
			on-closed: func [port /local job][
				foreach [id job] port/job-queue [job/4: 'pending]
				clear port/job-queue
				
				if all [
					object? port/locals
					not empty? port/locals/write-queue
				][
					clear port/locals/write-queue
				]
				reopen-port/no-close port
			]
			on-ready: func [port][
				if job: extapp-pop-job register-list [
					send-job job/2 port job
				]			
			]
		][
			id: none
		]
		false
	]
		
	; --- Decline if not fastcgi script	
	declined?: func [req][not find register-list req/handler]
	
	url-to-filename: func [req /local d? cfg domain ext new][
		d?: declined? req
		cfg: req/cfg
		if empty? trim req/in/target [		;-- trim should be done when target is parsed
			foreach file to-block any [select cfg 'default []][
				new: rejoin [cfg/root-dir req/in/path file]
				if req/file-info: info? new [
					req/in/target: form file
					if ext: find/last req/in/target dot [
						req/in/ext: to word! ext
						req/handler: select service/handlers req/in/ext
					]
					if not req/in/file [req/in/file: new]					
					if d?: declined? req [return false]
				]
			]
		]		
		either d? [
			false
		][
			if not req/in/file [
				req/in/file: rejoin [cfg/root-dir req/in/path req/in/target]
			]
			true
		]
	]
	
	set-mime-type: func [req][
		if declined? req [return none]		
		req/out/mime: 'text/html
		true
	]
	
	access-check: func [req /local info mdate][
		; --- This phase is redefined to avoid Last-Modified header generation
		; --- and 404 errors from mod-static (inappropriate here)
		
		if declined? req [return none]		
		true
	]
	
	send-job: func [req port job][
		port/id: seq-id
		repend port/job-queue [seq-id job]

		port/stats/1: port/stats/1 + 1
		seq-id: seq-id // 5000 + 1	;-- Limited to a smaller 16bits value (according to FCGI specs)

		insert-port port make fcgi-job-class [
			id: port/id
			client: service/client
			url: join req/in/path req/in/target
			;info: req/in/path
			path: form to-local-file get-modes req/in/file 'full-path
			script: any [req/in/script-name req/in/url]
			query: req/in/arg
			if req/auth/type [
				auth-type: form req/auth/type
				user: req/auth/user
			]
			headers: req/in/headers
			if content: req/in/content [
				cnt-length: select req/in/headers 'Content-Length
				cnt-type: select req/in/headers 'Content-Type
			]
			if req/in/method <> 'GET [method: form req/in/method]
		]
		job/4: 'sent
	]
	
	make-response: func [req /local port job][	
		if declined? req [return none]
		
		set [port job] extapp-make-job req

		if all [
			port
			;object? port/locals		; tested in mod-extapp
			empty? port/job-queue		; ?? empty is not accurate test, should test jobs flags, or port busy 
		][
			send-job req port job
		]
		true
	]
	
	logging: func [req][
		none
	]
	
	words: []
]
