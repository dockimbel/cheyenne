REBOL []

install-HTTPd-extension [
	name: 'mod-rsp
	verbose: 0
	
	webapps: make block! 4
		
	order: [
		url-to-filename	first
		make-response	first
	;	logging			last
		clean-up		first
		task-part		normal
		task-done		normal
		task-failed		normal
	]
	
	;====== Server events handling ======
	on-reload: does [
		set 'session-ctx reduce [
			sessions/list
			sessions/queue
		]
	]

	on-reloaded: does [
		sessions/list: session-ctx/1
		sessions/queue: session-ctx/2
		set 'session-ctx none
	]
	
	on-quit: func [svc /local flags][
		if all [
			attempt [flags: svc/conf/globals/persist]
			find flags 'sessions 
		][
			sessions/save-ctx
		]
	]
	
	on-started: does [
		sessions/load-ctx
	]
	;===================================
	
	default-error-page: {
		<html>
			<head><title>Page unavailable</title></head>
			<body><br><br><br><br><br><br><br><br><br><br><center>
				<font face="Arial">
				Sorry, this page cannot be displayed. Try again or contact the
				web site administrator.<br><br>
				<a href="$home">Go back to home page</a>
				</font>
			</center></body>
		</html>
	}
	
	form-error: func [evt obj [object!] /local errtype text][
		errtype: get in system/error obj/type
		text: get in errtype obj/id
		if block? text [text: reform bind/copy text obj]
		insert tail evt "** "
		insert tail evt errtype/type
		insert tail evt ": "
		insert tail evt text
		insert tail evt newline
		if obj/where [
			insert tail evt "** Where: "
			insert tail evt mold obj/where
			insert tail evt newline
		]
		if obj/near [
			insert tail evt "** Near: "
			insert tail evt mold/only obj/near
			insert tail evt newline
		]
	]
	
	log-error: func [req /local evt][
		evt: clear ""
		insert tail evt "----------------------"
		insert tail evt "^/Timestamp: "
		insert tail evt now/precise
		insert tail evt "^/Error:^/"
		form-error evt req/out/error
		insert tail evt "^/Request:^/"
		insert tail evt mold req/in
		insert tail evt newline
		write/append %rsp-errors.log evt
	]
	
	filter-error: func [req /local page][
		unless find req/cfg 'debug [
;			log-error req
			page: either page: select req/cfg 'error-page [
				req/out/forward: page
			][
				req/out/content: default-error-page
			]
			replace page "$home" any [all [req/app dirize req/app] "/"]
		]
	]

	send-msg: func [req sess /local job][
		job: compose/only [
			cfg	 (req/cfg)
			in 	 (req/in)
			ip 	 (service/client/remote-ip)
			port (service/client/local-port)
			session
		]
		either sess [
			append/only job compose/only [
				id	 	(sess/id)
				vars 	(sess/vars)
				queries (sess/cache-queries)
				app	 	(req/app)
				timeout (sess/timeout)
				init 	(sess/init)
			]
			sess/init: no
			sess/busy?: yes
		][
			append job none
		]
		service/module: 'RSP
		service/do-task mold/all job req
	]
	
	decode-msg: func [req /local ro value list sess close? login?][
		ro: req/out
		if verbose > 2 [log/info ro/content]
		
		parse first load/all ro/content [
			(ro/content: none)
			'status [
				set value string!    (
					ro/status-line: rejoin ["HTTP/1.1 " value crlf]
					ro/code: load copy/part value 3
				)
				| set value integer! (ro/code: value)
				| none!	   (ro/code: 200)
			]
			'headers [
				set list block! (
					foreach [name value] list [h-store ro/headers name value]
				)
				| none!
			]
			'content set value [string! | binary!] 		(ro/content: value)
			'forward set value [string! | url! | none!] (ro/forward: value)
			'error   set value [logic! | object!] 		(ro/error: value)
			'log?    set value [logic!] 				(ro/log?: value)
			'session [
				into [
					opt ['init (sess: sessions/create req)]
					'id [set value string! | none!] (
						sess: any [sess sessions/obtain value]
						sessions/set-cookie sess req
						login?: select sess/vars 'login?
					) 
					'vars set list block! (sess/vars: list)	
					'queries set list [block! | none!] (sess/cache-queries: list)
					'timeout set value time! (
						if sess/timeout <> value [
							sess/timeout: value
							sessions/refresh sess req
						]
					)
					opt ['close (close?: yes sessions/destroy sess req)]
					(sess/busy?: no)
					;	probe "@@@@@@@@@@@@@@@@@@@@@@@@@@"
					;	?? close?
					;	if not close? [sessions/set-cookie sess req]
					;)
				]
				| none!
			]
		]
;		if sess [
;			sess/busy?: no
;			if not close? [sessions/set-cookie sess req]
;		]
;		if all [
;			login? == no				;-- catch the switch of 'login? from no to yes
;			sess
;			select sess 'login?
;			select sess 'rescued
;		][
;			req/in: sess/rescued
;			req/out/forward: req/in/url
;		]
	]
	
	process-next-job: has [sess job req current][
		if set [sess job] sessions/pop-job [
			req: job/1
			current: service/client
			service/set-peer job/2
			send-msg req sess
			service/set-peer current
		]
	]
	
	process-webapp: func [req /local pos url sess][
		if any [
			not sess: sessions/exists? req 
			sess/app <> req/app
		][
			sess: sessions/create req
			repend sess/vars ['login? no]
;			if all [
;				find [PUT POST] req/in/method
;				req/in/content
;				100'000 > length? req/in/content
;			][
;				repend sess/vars ['rescued req/in]
;			]
		]
		either url: select req/cfg 'auth [
			either any [
				find/match req/in/path "/public/"
				select sess/vars 'login?
			][
				; TBD: set no-cache headers to avoid browser caching of protected ressources
				if declined? req [throw false]	; let other modules serve the allowed ressource	
			][
                unless url = rejoin [ ; test if the requested url is not the login URL 
                    req/app req/in/path any [
                        all [
                            slash = last url
                            find req/cfg/default to file! req/in/target
                            %""
                        ]
                        req/in/target
                    ] 
				][
					req/out/code: 302
					sessions/set-cookie sess req
					h-store req/out/headers 'Location url
					h-store req/out/headers 'Last-Modified none
					either pos: find sess/vars 'from [
						pos/2: req/in/url
					][
						repend sess/vars ['from req/in/url]
					]
					throw true 	; redirects to login page
				]
			]
		][
			if declined? req [throw false]	; no auth and not RSP ressource
		]
		sess
	]
	
	declined?: func [req]['RSP <> req/handler]
	
;=== HTTP Callbacks ===

	url-to-filename: func [req /local apps pos res][
		if apps: select webapps req/vhost [
			foreach [path cfg] apps [
				res: join req/in/path req/in/target
				if any [empty? path pos: find/match res path][
					if any [
						req/in/target = "app-init.r"
						all [pos find pos "private"]	; forbid /app/private, but allow /private/app
						all [not pos find res "private"]
					][
						req/out/code: 404
						return false
					]
					req/cfg: cfg
                    req/app: path
					unless empty? path [
						either empty? pos [
							req/app: none
							req/in/file: cfg/root-dir
						][
							req/in/path: find/match req/in/path path
						]
					]					
					break
				]
			]
		]
		false
	]
	
	make-response: func [req /local res sess][
		if all [declined? req none? req/app][return none]	
		
		if logic? res: catch [
			if req/app [sess: process-webapp req]
			
			unless req/in/file [
				req/in/file: join req/in/path req/in/target 
			]
			all [
				any [sess sess: sessions/exists? req]
				sessions/refresh sess req
				sess/busy?
				sessions/push-job sess req service/client
				return true
			]
			none
		][
			return res
		]		
		send-msg req sess
		true
	]
	
	logging: func [req][
		none
	]

	clean-up: func [req][
		if all [declined? req none? req/app][return none]
		if zero? remainder length? sessions/list 20 [sessions/gc]
		true
	]
	
	task-part: func [req /local ro res][
		if declined? req [return none]
		ro: req/out
		ro/code: 200
		res: load/all ro/content		
		if res/headers [		
			foreach [name value] res/headers [
				h-store ro/headers name value
			]
		]
		ro/content: res/content
		service/send-chunk req
		true
	]

	task-done: func [req /local page][
		if declined? req [return none]	;-- Check if this doesn't block some valid calls
		decode-msg req
		if req/out/error [filter-error req]
		process-next-job
		service/process-queue
		true 		
	]

	task-failed: func [req /local ro sess][
		if declined? req [return none]
		if sess: sessions/exists? req [sess/busy?: no]
		ro: req/out
		if verbose > 0 [log/info mold ro/content]
		unless any-string? ro/content [ro/content: mold ro/content]
		ro/code: 500
		process-next-job		
		service/process-queue	
		true
	]
	
;=== Config Options ===
	
	words: [
		;--- Allow databases declaration for background tasks
		databases: [block!] in globals
		
		;--- Define a new webapp structure
		webapp: [block!] in main do [
			use [new root h][
				new: reduce [root: select args/1 'virtual-root args/1]
				if slash = last root [remove back tail root]
				either h: select webapps vhost [
					either find h root [
						log/error ["webapp " root " already defined"]
					][
						append h new
					]
				][
					repend webapps [vhost new]
				]
			]
			unless find args/1 'default [
				repend args/1 ['default [%index.rsp %index.html]]
			]
			process args/1
		]

		;--- Define a unique URI for the webapp
		virtual-root: [string!] in main 

		;--- Trigger the authentication mode
		auth: [string!] in main
		
		;--- Redirect RSP errors pages to user-defined page
		error-page: [string!] in main		

		;--- Trigger the debugging mode
		debug: in main
		
		;--- Define the localization resources directory (relative to the webapp)
		locales-dir: [file!] in main do [
			if slash = last args/1 [remove back tail args/1]
		] 
		
		;--- Optionally define a default lang (if <> 'en). Use standard language codification xx[-yy].
		default-lang: [word!] in main
		
		;--- Set session timeout 
		timeout: [time!] in main
		
		;--- Set session's cookie domain, useful in case you want to share session between subdomains
		SID-domain: [string!] in main  

	]
	
;=== Session Management ===
	
	sessions: make log-class [
		name: 'RSP-Session
		verbose: 0
		
		list: make hash! 500
		queue: make block! 100 ; [sess [req client-port]...]
		
		random/seed now/time/precise

		SID-name: "RSPSID"
		SID-chars: charset [#"A" - #"Z"]
		ws: #" "
		
		ctx-file: join system/options/path %.rsp-sessions
		if cheyenne/port-id [append ctx-file join "-" cheyenne/port-id/1]
		
		proto: context [
			id: vars: start: expires: timeout: queue: init: app: auth: 
			cache-queries: busy?: cookie: none
		]
		
		generate-ID: has [out][
			out: make string! 24
			loop 24 [insert tail out #"@" + random/secure 26]
			uppercase out
		]
		
		save-ctx: does [
			foreach [id sess] list [
				sess/busy?: no
				clear sess/queue
			]
			attempt [write ctx-file mold/all list]
		]
		
		load-ctx: does [	
			attempt [
				if system/words/exists? ctx-file [
					list: load ctx-file
					delete ctx-file
				]
			]
		]
		
		create: func [req /local sess][
			sess: make proto [
				init: yes
				id: generate-ID
				vars: make block! 3
				start: now
				timeout: any [select req/cfg 'timeout 00:20]
				expires: start + timeout
				queue: make block! 3 ;-- [[req client-port]...]
				app: req/app
				host: select req/in/headers 'Host
				ip: service/client/remote-ip		;-- for security checks
				auth: busy?: no
			]
			sess/cookie: build-cookie sess select req/cfg 'SID-domain
			
			insert tail list sess/id
			insert tail list sess
			sess
		]
		
		check-SID: func [req data /local id sess][
			parse/all data [
				any [
					thru SID-name opt ws "=" opt ws
					copy id 24 SID-chars (
						if all [
							sess: select list id
							sess/app = req/app
							sess/host = select req/in/headers 'Host
							sess/ip = service/client/remote-ip
						][
							return sess
						]
					)
				]
			]
			none
		]
		
		exists?: func [req /local pos sess value][
			unless sess: any [
				all [pos: select req/in/headers 'Cookie check-SID req pos]	;-- by cookie
				all [pos: req/in/arg check-SID req pos]						;-- by URL
				all [														;-- by POST data
					value: select req/in/headers 'Content-type
					find/part value "application/x-www-form-urlencoded" 33
					pos: req/in/content
					check-SID req pos
				]
			][
				return none
			]
			if sess/expires < now [
				destroy sess req
				return none
			]
			sess
		]
		
		obtain: func [id][
			select list id
		]
		
		gc: does [
			remove-each [id sess] list [sess/expires < now]
		]
		
		push-job: func [sess req port /local job][
			repend/only sess/queue job: reduce [req port]
			repend queue [sess job]
		]

		pop-job: has [job][
			if empty? queue [return none]
			job: copy/part queue 2
			remove/part queue 2
			remove find/only job/1/queue job/2	;-- job/1=>sess, job/2=>[req port]
			job
		]
				
		refresh: func [sess req][
			sess/expires: now + sess/timeout
		]
		
		destroy: func [sess req][
			remove/part back find list sess 2
			sess/expires: none
			unless empty? sess/queue [
				log/warn join 
					"session closed, but queue not empty : " 
					length? sess/queue
			]
			h-store req/out/headers 'Set-Cookie
				build-cookie/delete sess select req/cfg 'SID-domain none
		]
		
		set-cookie: func [sess req][
			h-store req/out/headers 'Set-Cookie sess/cookie
		]
		
		build-cookie: func [sess domain /delete old /local out][
			out: make string! 128
			insert tail out SID-name
			insert tail out "="
			insert tail out any [old sess/id]
			if delete [
				insert tail out "; expires=Fri, 31-Dec-1999 23:59:59 GMT"
			]
			if domain [
				insert tail out "; domain="
				insert tail out domain 			
			]
			if sess/app [
				insert tail out "; path="
				insert tail out either empty? sess/app [#"/"][sess/app]
			]
			insert tail out "; HttpOnly"
			out
		]
	]
]
