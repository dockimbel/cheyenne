REBOL [
	Title: "RSP handler"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Version: 1.0.0
	Date: 27/05/2007
]

do-cache uniserve-path/libs/html.r
do-cache uniserve-path/libs/headers.r
do-cache uniserve-path/libs/decode-cgi.r
do-cache uniserve-path/libs/url.r
do-cache uniserve-path/libs/email.r

install-module [
	name: 'RSP

	verbose: 0
	
	libs: none
	apps: make block! 1 	; [app-dir events ctx ...]
	apps-db: make block! 1 	; [domain1 [app [db1 def1 ...] app2 [...] ...] domain2 [...] ...]
	databases: none
	jobs: make block! 1
	start-flag: close-flag: no
	splitted: none
	
	app-class: context [
		name: events: ctx: databases: none
	]
	
	evt-class: context [
		on-application-start: 
		on-application-end: 
		on-session-start: 
		on-session-end: 
		on-page-start:
		on-page-end: 
		none
	]

	save-path: copy system/options/path
	set 'halt set 'q set 'quit does [throw exit-value]

	set 'rsp-log func [v] compose [(:print) mold :v :v]		; <--DEPRECATED
	
	rsp-prin: func [data][insert tail response/buffer reform data]
	rsp-print: func [data][
		insert tail response/buffer reform data
		insert tail response/buffer newline
	]
	rsp-probe: func [data][insert tail response/buffer mold data data]
	rsp-print-funcs: reduce [:rsp-prin :rsp-print :rsp-probe]
	saved-print-funcs: reduce [:prin :print :probe]
	print-funcs: [prin print probe]
	
	exit-value: 987123654		;-- value used to mark script ending
	system/error/throw/no-function/1: "Return or Exit not in function, or Break not in loop"

	sandboxed-exec: func [rsp-script [function!] /local res][
		any [
			all [
				error? set/any 'res try [catch [rsp-script exit-value]]
				disarm :res
			]
			all [
				any [
					not value? 'res
					not :res == exit-value
				]
				make system/standard/error [type: 'throw id: 'no-function near: []]
			]
		]
	]
	
	form-error: func [err [object!] /local type id desc][	
		type: err/type
		id: err/id
		arg1: either unset? get/any in err 'arg1 [none][err/arg1]
		arg2: err/arg2
		arg3: err/arg3
		desc: reduce system/error/:type/:id
		reform [
			"^-**" system/error/:type/type #":" reduce system/error/:type/:id newline
			"^-** Where:" mold/flat err/where newline
			"^-** Near: " mold/flat err/near newline
		]
	]
	
	log-script-error: func [file err /with h][
		log/info [
			any [all [with h] "##RSP Script Error"] ": ^/^/"
			rejoin either request/parsed [
				[
					"^-URL  = " request/parsed/url
					"^/^-File = " file
					 "^/^/" form-error err
					"^/^/Request  = " mold request/parsed 
				]
			][
				["^-File = " file "^/^/" form-error err]
			]
		]
	]

	html-form-error: func [err [object!] file /event evt /local type id desc][	
		type: err/type
		id: err/id
		arg1: either unset? get/any in err 'arg1 [none][err/arg1]
		arg2: err/arg2
		arg3: err/arg3
		desc: reduce system/error/:type/:id
		print {
<HTML>
	<HEAD>
		<TITLE>
			RSP Error
		</TITLE>
	</HEAD>
	<BODY><FONT face="Arial">
		<BR>
		<CENTER>
		<H2>&gt; RSP Error Trapped &lt;</H2><BR>
		<TABLE border="1" cellspacing="0" cellpadding="0">}
		either event [ 
			print {
		<TR><TD align="right"><FONT face="Arial"><B>Event :</B></FONT></TD>
		<TD align="left"><FONT face="Arial">}print mold evt print{</FONT></TD></TR>}
		][
			print {
		<TR><TD align="right"><FONT face="Arial"><B>Script :</B></FONT></TD>
		<TD align="left"><FONT face="Arial">}print mold file print{</FONT></TD></TR>}
		]
		print {
		<TR><TD align="right"><FONT face="Arial"><B>Error Code :</B></FONT></TD>
		<TD align="left"><FONT face="Arial">}print mold err/code print{</FONT></TD></TR>
		<TR><TD align="right"><FONT face="Arial"><B>Description :</B></FONT></TD>
		<TD align="left"><FONT face="Arial">}print ["<I>"type " error ! </I><BR>"desc] print{</FONT></TD></TR>
		<TR><TD align="right"><FONT face="Arial"><B>Near :</B></FONT></TD>
		<TD align="left"><FONT face="Arial">}print html-encode mold/flat err/near print{</FONT></TD></TR>
		<TR><TD align="right"><FONT face="Arial"><B>Where :</B></FONT></TD>
		<TD align="left"><FONT face="Arial">}print html-encode mold/flat err/where print{</FONT></TD></TR>
		</TABLE>
		</CENTER>
	</BODY>
</HTML>
			}
	]

	safe-exec: func [file code /with h /local err][
		if err: sandboxed-exec :code [
			either with [
				log-script-error/with file err h
			][
				log-script-error file err 
			]
		]
	]

	safe-exec-files: func [list [block!]][
		foreach file list [
			if file? file [
				either exists? file [
					safe-exec/with file does [do file] "##User Library error"
				][
					log/error ["access error: cannot open " mold file]
				]
			]
		]
	]
	
	protected-exec: func [file code [block! function!] /event evt /local err thru?][
		unless thru?: :print = :rsp-print [set print-funcs rsp-print-funcs]
		if err: sandboxed-exec :code [		
			html-form-error err file			
			either event [
				log-script-error/with file err rejoin ["##Error in '" :evt " event"]
			][
				log-script-error file err
			]
			set print-funcs saved-print-funcs	
			return err
		]
		unless thru? [set print-funcs saved-print-funcs]
		false
	]
	
	get-app-db: func [defs [block!] /local hosts conn-list][
		if not hosts: select apps-db request/headers/host [
			repend apps-db [request/headers/host hosts: make block! 1]
		]
		if not conn-list: select hosts request/web-app [
			repend hosts [request/web-app conn-list: copy/deep defs]
		]
		conn-list
	]
	
	engine: context [
		list: make hash! 100
		current: none
		verbose: 0

		sandbox: context [
			__txt: func [s o][
				insert/part tail response/buffer at current s o
			]
			__cat: []
		]

		compile: func [entry /no-lang /local out value s e word id ctx][
			unless no-lang [
				id: locale/lang
				locale/set-default-lang
			]

			out: make string! 1024	
			parse/all current: fourth entry [
				any [
					end break
					| "#[" copy value to #"]" skip (
						append out reform [
							" prin any [pick __cat"
							locale/id? value
							mold value #"]"
						]
					)
					| "<%" [#"=" (append out " prin ") | none]
						copy value [to "%>" | none] 2 skip (
							if value [repend out [value #" "]]
						)
					| s: copy value [any [e: "<%" :e break | e: "#[" :e break | skip]] e: (
						append out reform [" __txt" index? s offset? s e #" "]
					)
				]
			]
			unless no-lang [locale/set-lang id]
			if error? try [out: load out][
				out: reduce ['load out]
			]
			if not block? out [out: reduce [out]]
			if all [
				value? 'request
				object? :request
				request/web-app
				ctx: find apps request/config/root-dir
			][
				out: bind out third ctx
			]		
			poke entry 3 out: does bind out sandbox	
			:out
		]

		refresh: func [entry file][
			poke entry 4 read file
			compile entry
		]

		add-file: func [path file /local pos][
			repend list [path modified? file none read file]
			skip tail list -4
		]
		
		dump: has [cnt][
			cnt: 1
			foreach [a b c d] list [
				log/info [a b]
				log/info ["code:" mold c]
				cnt: cnt + 1
			]
		]

		exec: func [path file /local code pos res][
			if verbose > 0 [
				log/info ["executing file: " mold file "path: " mold path]
			]				
			repend jobs [path current]
			code: either pos: find list path [
				if pos/2 < modified? file [refresh pos file]
				current: fourth pos				
				third pos
			][
				compile add-file path file
			]
			if verbose > 1 [log/info ["code: " mold second :code]]
			
			res: protected-exec path :code
			
			current: last jobs
			clear skip tail jobs -2
			if verbose > 2 [dump]
			response/error?: to logic! any [response/error? res] 		;-- Make TRUE persistant across nested executions
		]
	]
		
	debug-banner: context [
		active?: t0: none
		menu-head: read-cache %misc/debug-head.html
		menu-code: read-cache %misc/debug-menu.rsp
		menu: reduce [none 01/01/3000 none menu-code]
		engine/compile/no-lang menu
		
		insert-menu: has [buf pos body][
			unless active? [exit]
			buf: copy response/buffer
			clear response/buffer
			protected-exec %misc/debug-menu.rsp pick menu 3
			either pos: find buf "</head>" [
				insert pos menu-head
			][
				if body: find buf "<body" [
					insert body "^/<head>^/"
					insert body menu-head
					insert body "^/</head>^/"
				]
			]
			if any [body body: find buf "<body"] [
				insert find/tail body ">" response/buffer
			]
			clear response/buffer
			insert response/buffer buf
		]

		make-redirect-page: func [url][
			clear response/buffer
			append response/buffer {
				<html>
					<head></head>
					<body><font face="Arial"><center>
						<h2>Redirection Intercepted</h2>
						<br><br>Destination URL: }
			append response/buffer rejoin [
				{<a href="} url {">} url
				"</a></center></font></body></html>"
			]
		]

		on-page-start: does [
			t0: now/time/precise
			poke response/stats 1 0
			poke response/stats 2 0
		]

		on-page-end: has [pos time][
			if pos: find response/buffer "</body>" [
				time: to-integer 1000 * to-decimal (now/time/precise - t0)
				insert pos reform [
					"<br><br><small>Processed in :"
					either zero? time ["< 15"][time]
					"ms.<br>Real SQL queries :"
					response/stats/1
					"<br>Cached SQL queries :"
					response/stats/2
					"</small>"
				]
			]
		]
;		set 'debug? does [active?]
;		set 'show-debug does [active?: yes]
	]
	
	;--- public API ---
	
	set 'set-protected func [w [word!] value][
		unprotect :w
		set :w :value
		protect :w
	]
	
	set 'locale context [
		path: lang:	current: default: none
		cache: make block! 1
		alpha: charset [#"A" - #"Z" #"a" - #"z"]

		set-lang: func [id [word! none!] /local cats file][
			unless all [path id][return true]
			unless cats: select cache path [
				repend cache [path cats: make block! 1]
			]
			unless current: select cats id  [
				file: join path [mold id slash mold id ".cat"] 
				unless exists? file [return none]
				repend cats [id current: make hash! load file]
			]
			lang: id
			engine/sandbox/__cat: current
			true
		]
		get-path: does [
			join path [mold lang slash]
		]
		set 'say func [[catch] data [string! none!] /local cat][	
			unless all [current default data][return data]				
			any [
				all [
					cat: find/case default data
					cat: pick current index? cat
					cat
				]
				data
			]
		]
		id?: func [txt [string!] /local pos][		
			any [
				all [
					default
					pos: find/case default txt
					index? pos
				]
				0
			]
		]
		set-default-lang: does [
			set-lang any [select request/config 'default-lang 'en]
			default: current
		]
		decode-lang: has [id list v v2][
			unless path: select request/config 'locales-dir [exit]
			path: join request/config/root-dir [slash path slash]
			set-default-lang
			current: none
			if all [
				session/active?
				word? id: select session/content 'lang
			][
				if set-lang id [exit]
			]
			if id: select request/headers 'Accept-language [
				list: make block! 1
				parse id [
					some [
						copy v 1 8 alpha (append list v)
						opt [
							"-" copy v2 1 8 alpha
							(insert back tail list rejoin [v #"-" v2])
						]
						opt ","
					]
					";" thru end
				]
				foreach id list [
					if set-lang to word! id [exit]
				]
			]
		]
	]

	set 'do-sql func [
		[catch] db [word! path!] data [string! block! word!]
		/flat /local port out res defs
	][
		if not pos: any [
			all [
				word? :db
				 any [
					all [
						request/web-app
						defs: select request/config 'databases
						find get-app-db defs :db
					]
					find databases :db
				]
			]
			all [path? :db attempt [do :db]]
		][
			throw make error! reform ["database" :db "not defined!"]
		]
		port: pos/2
		either error? set/any 'res try [
			if any [block? port url? port][				
				poke pos 2 port: open port				
				unless port/handler [	;-- RT's drivers
					poke pos 2 port: first port
				]
			]
		
			either word? data [
				poke response/stats 2 response/stats/2 + 1
				db-cache/query db data flat
			][
				poke response/stats 1 response/stats/1 + 1
				either value? 'send-sql [
					either flat [
						send-sql/flat port data
					][
						send-sql port data
					]
				][
					either port/handler [
						any [
							insert port data
							copy port
						]
					][							;-- RT's drivers
						insert port data
						either flat [
							out: make block! 8
							until [if data: pick port 1 [append out data] data]
							out
						][
							attempt [copy port]
						]
					]
				]
			]
		][
			throw res
		][
			all [value? 'res res]
		]
	]
	
	set 'db-cache context [
		data: make block! 1  ; ['db ['class [...] ...] ...]
		sync-list: none

		sync: func [list [block! none!] /local times][	
			if none? sync-list [sync-list: list]
		]
		
		define: func [[catch] db [word!] spec [block!] /local pos times][
			parse spec [
				some [
					pos: string! (
						change/only pos reduce [01/01/0001 pos/1 make block! 16]
					)
					| skip
				]
			]
			repend data [db spec]
			unless sync-list [sync-list: make block! length? spec]
			times: make block! 1
			loop (length? spec) / 2 [append times now]
			either pos: find sync-list db [
				change/only next pos times
			][
				repend sync-list [db times]
			]
		]
		
		query: func [
			[catch] 
			db [word!] class [word!] flat [logic! none!]
			/local cache pos modified
		][
			cache: second pos: find data/:db class			
			modified: pick sync-list/:db (index? next pos) / 2
			if cache/1 <> modified [
				cache/1: modified
				clear cache/3
				append cache/3 either flat [
					do-sql/flat db cache/2
				][
					do-sql db cache/2
				]
			]
			copy cache/3
		]
		
		invalid: func [[catch] db [word!] class [word! block!] /local cache list][
			if word? class [class: reduce [class]]
			cache: data/:db
			list: sync-list/:db
			foreach w class [
				poke list (index? next find cache w) / 2 now
			]
		]
	]
	
	set 'request context [
		content: headers: method: posted: client-ip: server-port: 
		translated: parsed: config: web-app: web-socket?: none
		
		query-string: has [out][
			out: make string! 32
			foreach-nv-pair content [
				insert tail out name
				insert tail out #"="
				insert tail out url-encode any [
					all [any-string? value value]
					form value
				]
				insert tail out #"&"
			]
			remove back tail out
			out
		]
		
		store: func [spec [block!] target [file!]][
			if slash = last target [join target spec/1]
			
			either file? spec/2 [
				call/wait reform [
					pick ["move /Y" "mv"] system/version/4 = 3
					to-local-file spec/2
					to-local-file target
				]
			][
				write/binary target spec/2
			]
		]
	]
	
	set 'response context [
		buffer: buffer*: make string! 1024 * 64
		headers: status: forward-url: none
		buffered?: yes
		compress?: yes
		log?: yes
		error?: no
		cache-list: make block! 1
		stats: [0 0]	; [real-sql-requests sql-cache-hits]
		
		set-status: func [code [integer!] /msg str [string!]][
			status: any [all [msg reform [code str]] code]
		]
		set-cookie: func [][]
		set-header: func [word [word!] value [string! none!] /add /local pos][
			unless headers [headers: make block! 1]
			either all [not add pos: find headers word][
				change next pos value
			][
				insert tail headers word
				insert tail headers value
			]
		]
		end: does [throw exit-value]
		reset: does [
			buffer: buffer*
			clear buffer
		]
		redirect: func [url [string! url!] /strict /thru /last][
			either debug-banner/active? [
				debug-banner/make-redirect-page url
			][
				set-status any [all [strict 303] all [thru 307] all [last 301] 302]
				set-header 'Location form url
			]
			end
		]
		auto-flush: func [mode [logic!]][
			;--TDB
		]
		flush: func [/end][
			if buffered? [buffered?: no]
			if all [not end empty? buffer][exit]		; don't send a false 0-length body
			server-send-data mold/all compose/only/deep [
				part [content (buffer) headers (headers)]
			]
			reset
		]
		cache: func [time [time!]][insert tail cache-list time]
		cache-delete: func [url [url!]][insert tail cache-list time]
		forward: func [[catch] url [string! url!]][
			if any [
				all [string? url slash <> first url]
				all [url? url not get in parse-url url 'target]
			][			
				throw make error! "invalid URL argument"
			]
			unless buffered? [
				throw make error! "forward cannot be used after flush"
			]
			unless empty? buffer [reset]
			forward-url: url
			end
		]
		no-log: does [log?: no]
		no-compress: does [compress?: no]
	]
	
	set 'session context [
		content: timeout: events: id: none
		active?: init?: no
		
		add: func [name [word!] value /local pos][
			either pos: find content name [
				change/only next pos value
			][
				repend content [name value]
			]
		]
		
		remove: func [name [word!]][
			system/words/remove/part find content name 2
		]
		
		exists?: func [name [word!]][
			to logic! find content name
		]
		
		start: does [
			unless active? [
				start-flag: yes
				close-flag: no
				content: make block! 1
				id: none
			]
			true
		]
		
		reset: does [
			if active? [
				;change-dir request/config/root-dir
				if exists? 'login? [content/login?: no]
				fire-event 'on-session-start
				;change-dir save-path
			]
		]
		
		end: does [
			start-flag: no
			close-flag: yes	
		]
	]
	
	set 'include func [file [file!] /local blk path count][
		count: [0]
		either count/1 > 5 [
			print "### Include RSP failed: max inclusion level reached! ###"
			log/warn ["include RSP failed: max inclusion level reached - file: " mold file]
		][
			count/1: count/1 + 1
			path: first splitted
			either slash = first file [
				blk: split-path file 
				engine/exec join path first blk second blk
			][
				engine/exec join path file file
			]
			count/1: count/1 - 1
		]		
		if all [
			integer? response/status
			response/status >= 300
		][
			response/end
		]
	]
	set 'include-file func [file [file!]][
		insert tail response/buffer read file
	]
	
	set 'validate func [[catch] spec [block!] /full /local vars value invalid pos m?][
		full: to logic! full
		if error? try [
			vars: request/content
			value: pick [[name type m?][name type]] full
			foreach :value spec [
				either pos: find vars name [
					either empty? value: pick pos 2 [
						poke pos 2 value: none
					][
						if all [
							type <> '-
							not attempt [poke pos 2 to get type value]
						][
							unless invalid [invalid: make block! 1]
							insert tail invalid name
						]
					]
				][
					insert tail vars name
					insert tail vars value: none
				]
				if all [none? :value m? m? = '*][
					unless invalid [invalid: make block! 1]
					insert tail invalid name
				]
			]
		][throw make error! "invalid spec block!"]
		invalid
	]
	
	set '*do :do
	
	set 'do func [[catch] value	/args arg /next /global /local depth][	
		if global [return *do value]
		if args [return *do/args value arg]
		if next [return *do/next value]
		unless file? :value [return *do :value]	

		depth: [0]		
		either request/web-app [
			if arg: find apps request/config/root-dir [
				;bind value: load value arg/3
				value: load value
				depth/1: depth/1 + 1
				either depth/1 = 1 [
					if 1 < length? depth [				
						foreach blk at depth 2 [arg/3: make arg/3 blk] ; triggers sub 'do
						clear at depth 2
					]
					arg/3: make arg/3 value
				][
					append/only depth :value
				]
				depth/1: depth/1 - 1
				;if all [zero? depth/1 1 < length? depth][
				;	foreach blk at depth 2 [arg/3: make arg/3 blk] ; trigger sub 'do
				;	clear at depth 2
				;]
			]
		][*do value]
	]

	;--- end of public API ---
	
	lf: #"^/"
	nl: [crlf | cr | lf]
	crlfx2: join crlf crlf
	dquote: #"^""
	
	reset-response-object: does [
		clear response/cache-list
		response/status: response/forward-url: none
		response/buffered?: yes
		response/log?: yes
		response/compress?: yes
		response/error?: no
		if response/headers [clear response/headers]
		;if empty? jobs [
		response/reset
		;]
	]
	
	;-- quick implementation of multipart decoding :
	;	- doesn't support multipart/mixed encoding yet
	;	- doesn't parse all optional headers
	
	decode-multipart: func [data /local bound list name filename value pos][	
		list: make block! 2
		attempt [
			parse/all request/headers/Content-type [
				thru "boundary=" opt dquote copy bound [to dquote | to end]
			]
			unless bound [return ""]	 ;-- add proper error handler
			insert bound "--"	
			parse/all data [
				some [
					bound nl some [
						thru {name="} copy name to dquote skip
						[#";" thru {="} copy filename to dquote | none]
						thru crlfx2 copy value [to bound | to end] (
							insert tail list to word! name
							trim/tail value ; -- delete ending crlf
							if all [
								#"%" = pick value 1
								".tmp" = skip tail value -4
							][
								value: load value
							]
							either filename [
								insert/only tail list reduce [filename value]
							][
								insert tail list value
							]
							filename: none
						) | "--"
					]
				]
			]
		]
		list
	]

	decode-params: has [list value pos][
		list: make block! 1
		any [
			all [
				request/web-socket?
				list: reduce ['data as-string request/parsed/content]
			]
			all [
				value: select request/headers 'Content-type
				find/part value "multipart/form-data" 19
				list: decode-multipart request/posted
			]
			all [
				request/posted
				value: select request/headers 'Content-type
				find/part value "application/x-www-form-urlencoded" 33
				list: decode-cgi/raw/with request/posted list
			]
		]	
		if value: request/parsed/arg [
			if pos: find/last value #"#" [
				clear at value: copy value index? pos
			]						
			list: decode-cgi/raw/with value list
		]		
		request/content: list
	]
	
	decode-msg: func [data /local value list init?][
		parse load/all data [
			'cfg  set value block! 	 (request/config: value)
			'in	  set value object!	 (request/parsed: value)
			'ip   set value tuple!	 (request/client-ip: value)
			'port set value integer! (request/server-port: value)
			'session [
				into [
					(session/active?: yes)
					'ID 	 set value string!	(session/id: value)
					'vars 	 set list  block! 	(session/content: list)
					'queries set list  [block! | none!] (db-cache/sync list)
					'app  	 set value [string! | none!]  (request/web-app: value)
					'timeout set value time!	(session/timeout: value)
					'init 	 set value logic!	(session/init?: value)
				]
				| none! (
					session/active?: session/init?: no
					session/content: session/id: none
					request/web-app: none
				)
			]
		]
		request/method: request/parsed/method
		request/posted: request/parsed/content
		request/headers: request/parsed/headers
		request/web-socket?: request/parsed/ws?
		request/translated: join request/config/root-dir [
			request/parsed/path
			request/parsed/target
		]
		if all [
			find request/config 'debug
			not request/web-socket?
		][
			debug-banner/active?: yes
		]
	]
	
	fire-event: func [event [word!]][
		protected-exec/event request/parsed/file get in session/events :event :event
	]
	
	process-events: has [evt-data events ctx init root][	
		either request/web-app [
			root: request/config/root-dir
			either events: select apps root [
				session/events: events
			][
				safe-exec %app-init.r does [init: load join root %/app-init.r]
				evt-data: any [init []]
				repend apps [
					root
					events: make evt-class evt-data
					ctx: context []
				]
				session/events: events
				change-dir root
				fire-event 'on-application-start
				ctx: third find apps root				 ; ctx needs to reference the new object				
				foreach fun next first events [
					bind second get in events :fun ctx
				]
				;fire-event 'on-application-start
				system/script/path: dirize save-path
			]			
			if session/init? [
				change-dir root
				fire-event 'on-session-start
				change-dir save-path
			]
		][
			session/events: none
		]
	]
	
	build-msg: has [res sess][	
		res: compose/only [
			status	(response/status)
			headers	(response/headers)
			content (response/buffer)
			forward (response/forward-url)
			error	(response/error?)
			log?    (response/log?)
			session
		]
		either any [session/active? start-flag][
			sess: compose/only [
				id	 	(session/id)
				vars 	(session/content)
				queries (db-cache/sync-list)
				timeout (session/timeout)
			]
			if start-flag [insert sess 'init]
			if close-flag [append sess 'close]
			append/only res sess
		][
			append res none
		]
		mold/all res
	]
	
	compress-output: has [value buf][
		if all [
			not response/error?
			not request/web-socket?
			response/compress?
			not empty? buf: response/buffer
			512 < length? buf
			value: select request/parsed/headers 'Accept-Encoding
			find value "deflate"			
		][
			response/buffer: buf: skip compress buf 2
			clear skip tail buf -4
			response/set-header 'Content-Encoding "deflate"
		]
	]	

	on-task-received: func [data /local file events page-events?][
		if verbose > 0 [
			log/info "New job received :" 
			log/info mold data
		]
		session/events: none
		close-flag: start-flag: no
		debug-banner/active?: no

		decode-msg data
		process-events
		decode-params
		locale/decode-lang
		reset-response-object
		clear jobs

		file: request/translated
		if verbose > 0 [log/info ["calling script: " mold file]]
		change-dir first splitted: split-path file
		
		page-events?: all [session/events not request/web-socket?]
		
		if debug-banner/active? [debug-banner/on-page-start]
		if page-events? [fire-event 'on-page-start]
		
		unless all [
			integer? response/status
			response/status >= 300
		][
			engine/exec file last splitted
		]
		
		if page-events? [fire-event 'on-page-end]
		if debug-banner/active? [debug-banner/on-page-end]
		
		if verbose > 2 [log/info mold response/buffer]
		unless empty? response/buffer [debug-banner/insert-menu]
		change-dir save-path
		
		compress-output
		
		all [
			not response/buffered?
			not empty? response/buffer
			response/flush
			response/flush/end
		]
		request/web-app: none	; disables 'do sandboxing (avoid side-effects with other modules)
		result: build-msg
	]
	
	on-quit: has [blk][
		foreach [app-dir events ctx] apps [
			safe-exec %on-application-end events/on-application-end
		]
		
		if all [libs blk: select libs 'on-quit][safe-exec-files blk]
		
		if block? databases [
			parse databases [any [set p port! (attempt [close p]) | skip]]
		]
	]
	
	;--- Initialization ---
	
	file: %httpd.cfg
	all [
		any [
			all [
				exists? file
				block? conf: load/all file
			]
			all [
				exists?-cache file
				block? conf: load-cache file
			]
		]
		parse conf [
			thru 'globals into [
				any [
					'databases set databases block!
					| 'worker-libs set libs block!
					| skip
				]
			]
		]
	]
	if libs [safe-exec-files libs]
]

protect [
	do-sql db-cache request response session include
	include-file validate locale say do
]
