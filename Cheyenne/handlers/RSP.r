REBOL [
	Title: "RSP handler"
	Author: "SOFTINNOV / Nenad Rakocevic"
]

do-cache uniserve-path/libs/html.r
do-cache uniserve-path/libs/headers.r
do-cache uniserve-path/libs/decode-cgi.r
do-cache uniserve-path/libs/url.r
do-cache uniserve-path/libs/email.r

;-- Patch for COLLECT internal 'do
if all [value? 'collect pos: find second :collect 'do][pos/1: '*do]

install-module [
	name: 'RSP

	verbose: 0
	
	libs: none
	apps: make block! 1 	; [app-dir events ctx ...]
	databases: [global []] 	; [global [db1 def1 cache1...] domain1 [app [db1 def1 cache1...] app2 [...] ...] domain2 [...] ...]
	jobs: make block! 1
	splitted: port: none
	
	evt-class: context [
		on-application-start: 
		on-application-end: 
		on-database-init:
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
	
	set 'emit func [data [series!]][insert tail response/buffer reduce data]
	
	exit-value: 987123654		;-- value used to mark script ending
	system/error/throw/no-function/1: "Return or Exit not in function, or Break not in loop"


	reduce-error: func [err [object!] /local desc][
		;-- workaround for 'arg1 usage instead of :arg1 in some error blocks
		err/arg1: either unset? get/any in err 'arg1 [none][get/any in err 'arg1]
		;-- extend error object with a locally bound description field
		desc: system/error/(err/type)/(err/id)	
		make err compose/only [desc: (desc)]
	]
	
	sandboxed-exec: func [rsp-script [function!] /local res][
		any [
			all [
				error? set/any 'res try [catch [rsp-script exit-value]]
				reduce-error disarm :res
			]
			all [
				any [
					not value? 'res
					not :res == exit-value
				]
				reduce-error make system/standard/error [type: 'throw id: 'no-function near: []]
			]
		]
	]
	
	form-error: func [err [object!]][	
		reform [
			"^-**" system/error/(err/type)/type #":" reduce err/desc newline
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

	html-form-error: func [err [object!] file /event evt][
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
		<TR><TD align="right"><FONT face="Arial"><B>Event&nbsp;</B></FONT></TD>
		<TD align="left"><FONT face="Arial">}print mold evt print{</FONT></TD></TR>}
		][
			print {
		<TR><TD align="right"><FONT face="Arial"><B>Script&nbsp;</B></FONT></TD>
		<TD align="left"><FONT face="Arial">}print mold file print{</FONT></TD></TR>}
		]
		print {
		<TR><TD align="right"><FONT face="Arial"><B>Error Code&nbsp;</B></FONT></TD>
		<TD align="left"><FONT face="Arial">}print mold err/code print{</FONT></TD></TR>
		<TR><TD align="right"><FONT face="Arial"><B>Description&nbsp;</B></FONT></TD>
		<TD align="left"><FONT face="Arial">}print ["<I>" err/type " error ! </I><BR>" err/desc] print{</FONT></TD></TR>
		<TR><TD align="right"><FONT face="Arial"><B>Near&nbsp;</B></FONT></TD>
		<TD align="left"><FONT face="Arial">}print html-encode mold/flat err/near print{</FONT></TD></TR>
		<TR><TD align="right"><FONT face="Arial"><B>Where&nbsp;</B></FONT></TD>
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
			if debug-banner/active? [
				switch any [attempt [debug-banner/opts/error] 'inline][
					inline [html-form-error err file]
					popup  [debug-banner/rsp-error: make err [src: file]]
				]
			]
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
	
	get-app-db: func [defs [block!] /local hosts ports list][
		unless hosts: select databases request/headers/host [
			repend databases [request/headers/host hosts: make block! 1]
		]
		unless pos: find hosts request/web-app [
			repend hosts [request/web-app ports: copy/deep defs list: make block! 1]
			fire-event 'on-database-init		
		]
		any [ports pos/2]
	]
	
	relative-path: func [src dst /local i][
		src: remove parse src "/"
		dst: remove parse get-modes dst 'full-path "/"
		if src/1 <> dst/1 [return none]					;-- requires same root

		i: 1 + length? src 
		repeat c i - 1 [if src/:c <> dst/:c [i: c break]]	
		dst: to-file at dst i
		src: at src i
		unless tail? src [loop length? src [insert dst %../]]
		dst
	]
	
	engine: context [
		list: make hash! 100
		current: none
		verbose: 0

		sandbox: context [
			__txt: func [s o][
				insert/part tail response/buffer at current s o
			]
			__emit: func [data][if data [insert tail response/buffer data]]
			__cat: []
		]

		compile: func [entry /no-lang /local out value s e word id ctx close?][
			if all [
				entry/1								;-- avoid internal RSP debug scripts
				%.r = suffix? entry/1				;-- only check pure REBOL scripts
				error? try [load as-string entry/4]	;-- test if REBOL script is LOAD-able
			][
				out: reduce ['load entry/4]			;-- return a reproducible error as result
			]
			unless no-lang [
				id: locale/lang
				locale/set-default-lang
			]
			unless out [
				either out: attempt [load/header current: as-string entry/4][
					remove out 						;-- discards the header object
				][
					out: make string! 1024	
					parse/all current [
						any [
							end break
							| "#[" copy value to #"]" skip (
								append out reform [
									" prin any [pick __cat"
									locale/id? value
									mold value #"]"
								]
							)
							| "<%" (close?: no) [
								#"=" (append out " __emit ")
								| #"?" (append out " __emit reduce [" close?: yes)
								| none
							   ] copy value [to "%>" | none] 2 skip (
									if value [repend out [value #" "]]
									if close? [append out #"]"]
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
				]
			]
			unless block? out [out: reduce [out]]
			if all [
				entry/1							;-- avoid internal RSP debug scripts
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
		
		rebind: func [path file /local entry][
			if all [
				entry: find list path
				entry/1							;-- avoid internal RSP debug scripts
				request/web-app
				ctx: find apps request/config/root-dir
			][
				bind second third entry third ctx
			]
		]

		add-file: func [path file /local pos][
			repend list [path modified? file none read file]
			skip tail list -4
		]
		
		dump: has [cnt][
			cnt: 1
			foreach [a b c d] list [
				log/info reform [a b]
				log/info ["code:" mold c]
				cnt: cnt + 1
			]
		]

		exec: func [path file /local code pos res][
			if verbose > 0 [
				log/info reform ["executing file: " mold file "path: " mold path]
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
			
			;-- FIX: issue with MySQL server when connection times out
			;-- worker process is now killed to ensure a clean state  
			if all [
				object? :res
				res/id = 'timeout
			][
				s-quit
			]

			response/error?: to logic! any [response/error? res] 		;-- Make TRUE persistant across nested executions
		]
	]
	
	;--- public API ---
	
	alpha: charset [#"a" - #"z" #"A" - #"Z"]
	numeric: charset "0123456789"
	alpha-num: union alpha numeric
	domain-chars: union alpha-num charset "-"
	specials: charset "!.#$%&*+-=_|~"
	email-chars: union alpha-num specials
	
	email-rule: [
		some [".." break | email-chars] #"@" [some [some domain-chars #"."] 2 6 alpha]
	]
	
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
			copy any [
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
		/flat /info /local out res defs pos
	][
		unless pos: any [
			all [
				word? :db
				any [
					all [
						request/web-app
						defs: select request/config 'databases
						find get-app-db defs :db
					]
					all [
						pos: find databases/global :db
						any [all [empty? pos/3 fire-event 'on-database-init] true]
						pos
					]
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
			if info [return port]
		
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
							while [data: pick port 1][append out data]
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
		sync-list: none
		
		get-cache: func [name [word!] /init /local data][
			unless any [
				all [
					data: select databases request/headers/host
					data: find data request/web-app
					data: third data
					any [init block? data: select data :name]
				]
				all [
					data: find databases/global :name
					data: third data
					any [init block? data: select data :name]
				]
			][
				make error! rejoin ["Database '" :name " cache not found!"]
			]
			data
		]
		
		define: func [[catch] db [word!] spec [block!] /local pos][
			parse spec [
				some [
					pos: string! (
						change/only pos reduce [01/01/0001 pos/1 make block! 16]
					)
					| skip
				]
			]
			repend get-cache/init :db [db spec]
		]
		
		query: func [
			[catch] 
			db [word!] class [word!] flat [logic! none!]
			/local cache pos classes modified times list
		][
			cache: second pos: find list: get-cache :db class
			unless sync-list [sync-list: make block! length? list]
			unless find sync-list db [
				times: array/initial (length? list) / 2 now
				either classes: find sync-list db [
					change/only next classes times
				][
					repend sync-list [db times]
				]
			]			
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
		
		invalid: func [[catch] db [word!] class [word! block!] /local cache list pos][		
			if word? class [class: reduce [class]]
			cache: get-cache :db
			unless sync-list [sync-list: make block! length? cache]
			if list: select sync-list :db [
				foreach w class [
					if pos: find cache w [
						poke list (index? next pos) / 2 now
					]
				]
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
		
		store: func [[catch] spec [block!] /as target [file!] /local src path save-dir][
			either as [
				if slash = last target [target: join target spec/1]
				src: split-path spec/2
				unless path: relative-path src/1 target [
					if exists? target [
						throw make error! reform [target "already exists."]
					]
					call/wait reform [					;-- fallback method
						pick ["move /Y" "mv"] system/version/4 = 3
						to-local-file spec/2
						target: to-local-file target
					]
					return target
				]
			][
				src: split-path spec/2
				path: spec/1
			]
			if exists? target: join src/1 path [
				throw make error! reform [target "already exists."]
			]
			save-dir: system/script/path
			change-dir src/1
			rename src/2 path							;-- use rename trick to move file
			change-dir save-dir
			clean-path target
		]
	]
	
	set 'response context [
		buffer: buffer*: make string! 1024 * 64
		headers: status: forward-url: none
		buffered?: yes
		compress?: yes
		log?: yes
		error?: no						;-- must be a logic! value
		cache-list: make block! 1
		stats: [0 0]	; [real-sql-requests sql-cache-hits]

		reset-object: does [
			clear cache-list
			status: forward-url: none
			buffered?: log?: compress?: yes
			error?: no
			if headers [clear headers]
			reset
		]

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
		_start?: _close?: no
		
		reset-object: does [
			_start?: _close?: false
			events: none
		]
		
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
				_start?: yes
				_close?: no
				content: make block! 1
				id: none
			]
			active?
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
			_start?: no
			_close?: yes	
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
		if error? try [
			vars: request/content
			value: pick [[name type m?][name type]] to logic! full
			foreach :value spec [
				either pos: find vars name [
					either empty? value: pos/2 [
						pos/2: value: none
					][
						if any [
							all [
								type = 'email!
								not parse/all value email-rule
							]
							all [
								type <> '-
								not attempt [pos/2: to get type value]
							]
						][
							unless invalid [invalid: make block! 1]
							insert tail invalid name
						]
					]
				][
					insert tail vars name
					insert tail vars value: none
				]				
				if all [none? :value m?][
					if m? = '* [
						unless invalid [invalid: make block! 1]
						insert tail invalid name
					]
					unless find [* -] m? [
						pos: find vars name
						pos/2: any [all [series? m? copy m?] m?]
					]
				]
			]
		][throw make error! "invalid spec block!"]
		invalid
	]
	
	set '*do :do
	
	set 'do func [[catch] value	/args arg /next /global /local depth][	
		if global [return *do :value]
		if args [return *do/args value arg]
		if next [return *do/next value]
		unless file? :value [return *do :value]	

		depth: [0]		
		either request/web-app [
			if arg: find apps request/config/root-dir [
				value: load value
				depth/1: depth/1 + 1
				either depth/1 = 1 [
					if 1 < length? depth [
						foreach blk at depth 2 [arg/3: make arg/3 blk] ; triggers sub 'do
						clear at depth 2
					]
					arg/3: make arg/3 value
					if all [request/translated splitted][
						engine/rebind request/translated last splitted
					]				
				][
					append/only depth :value
				]
				depth/1: depth/1 - 1
			]
		][*do value]
	]

	set 'load-json use [
		tree branch here val flat? emit new-child to-parent neaten
		space comma number string block object _content value
	] [
		branch: make block! 10
		emit: func [val] [here: insert/only here val]
		new-child: [(insert/only branch insert/only here here: copy [])]
		to-parent: [(here: take branch)]
		neaten: [
			(new-line/all head here true)
			(new-line/all/skip head here true 2)
		]
		space: use [space] [
			space: charset " ^-^/^M"
			[any space]
		]
		comma: [space #"," space]
		number: use [dg ex nm as-num] [
			dg: charset "0123456789"
			ex: [[#"e" | #"E"] opt [#"+" | #"-"] some dg]
			nm: [opt #"-" some dg opt [#"." some dg] opt ex]
			as-num: func [val /num] [
				num: load val
				all [
					parse val [opt "-" some dg]
					decimal? num
					num: to-issue val
				]
				num
			]
			[copy val nm (val: as-num val)]
		]
		string: use [ch dq es hx mp decode] [
			ch: complement charset {\"}
			es: charset {"\/bfnrt}
			hx: charset "0123456789ABCDEFabcdef"
			mp: [#"^"" {"} #"\" "\" #"/" "/" #"b" "^H" #"f" "^L" #"r" "^M" #"n" "^/" #"t" "^-"]
			decode: use [ch mk escape to-utf-char] [
				to-utf-char: use [os fc en] [
					os: [0 192 224 240 248 252]
					fc: [1 64 4096 262144 16777216 1073741824]
					en: [127 2047 65535 2097151 67108863 2147483647]
					func [int [integer!] /local char] [
						repeat ln 6 [
							if int <= en/:ln [
								char: reduce [os/:ln + to integer! (int / fc/:ln)]
								repeat ps ln - 1 [
									insert next char (to integer! int / fc/:ps) // 64 + 128
								]
								break
							]
						]
						to-string to-binary char
					]
				]
				escape: [
					mk: #"\" [
						es (mk: change/part mk select mp mk/2 2)
						| #"u" copy ch 4 hx (
							mk: change/part mk to-utf-char to-integer to-issue ch 6
						)
					] :mk
				]
				func [text [string! none!] /mk] [
					either none? text [copy ""] [
						all [parse/all text [any [to "\" escape] to end] text]
					]
				]
			]
			[#"^"" copy val [any [some ch | #"\" [#"u" 4 hx | es]]] #"^"" (val: decode val)]
		]
		block: use [list] [
			list: [space opt [value any [comma value]] space]
			[#"[" new-child list #"]" neaten/1 to-parent]
		]
		_content: [#"{" space {"_content"} space #":" space value space "}"]
		object: use [name list as-object] [
			name: [
				string space #":" space
				(emit either flat? [to-tag val] [to-set-word val])
			]
			list: [space opt [name value any [comma name value]] space]
			as-object: [(unless flat? [here: change back here make object! here/-1])]
			[#"{" new-child list #"}" neaten/2 to-parent as-object]
		]
		value: [
			"null" (emit none)
			| "true" (emit true)
			| "false" (emit false)
			| number (emit val)
			| string (emit val)
			| _content (emit val)
			| object | block
		]
		func [
			[catch] "Convert a json string to rebol data"
			json [string! binary! file! url!] "JSON string"
			/flat "Objects are imported as tag-value pairs"
		] [
			flat?: :flat
			tree: here: copy []
			if any [file? json url? json] [
				if error? json: try [read (json)] [
					throw :json
				]
			]
			unless parse/all json [space opt value space] [
				make error! "Not a valid JSON string"
			]
			pick tree 1
		]
	]

	set 'to-json use [
		json emit emits escape emit-issue
		here comma block object value
	] [
		emit: func [data] [repend json data]
		emits: func [data] [emit {"} emit data emit {"}]
		escape: use [mp ch es encode] [
			mp: [#"^/" "\n" #"^M" "\r" #"^-" "\t" #"^"" {\"} #"\" "\\" #"/" "\/"]
			ch: complement es: charset extract mp 2
			encode: func [here] [change/part here select mp here/1 1]
			func [txt] [
				parse/all txt [any [txt: some ch | es (txt: encode txt) :txt]]
				head txt
			]
		]
		emit-issue: use [dg nm] [
			dg: charset "0123456789"
			nm: [opt "-" some dg]
			[(either parse/all here/1 nm [emit here/1] [emits here/1])]
		]
		comma: [(if not tail? here [emit ","])]
		block: [(emit "[") any [here: value here: comma] (emit "]")]
		object: [
			(emit "{")
			any [
				here: [tag! | set-word!] (emit [{"} escape to-string here/1 {":}])
				here: value here: comma
			]
			(emit "}")
		]
		value: [
			number! (emit here/1)
			| [logic! | 'true | 'false] (emit form here/1)
			| [none! | 'none] (emit 'null)
			| date! (emits to-idate here/1)
			| issue! emit-issue
			| [
				any-string! | word! | lit-word! | tuple! | pair! | money! | time!
			] (emits escape form here/1)
			| into [some [tag! skip]] :here (change/only here copy first here) into object
			| any-block! :here (change/only here copy first here) into block
			| object! :here (change/only here third first here) into object
			| any-type! (emits [type? here/1 "!"])
		]
		func [data] [
			json: make string! ""
			if parse compose/only [(data)] [here: value] [json]
		]
	]

	debug-banner: context [
		active?: t0: opts: trace.log: rsp-error: none
		menu-head: read-cache %misc/debug-head.html
		menu-code: read-cache %misc/debug-menu.rsp
		menu: reduce [none 01/01/3000 none menu-code]
		engine/compile/no-lang menu
		bind second pick menu 3 self

		default-page: "<html><head><title>RSP Error</title></head><body></body></html>"

		opts-default: context [
			lines: 50
			colors: [lawngreen black]
			error: 'popup
			ip: none
		]

		reset: does [
			opts: rsp-error: none
			active?: no
			response/stats/1: 0
			response/stats/2: 0
		]

		allowed-ip?: does [
			any [
				none? opts/ip
				opts/ip = request/client-ip
			]
		]

		no-menu?: does [
			any [
				not active?
				not allowed-ip?
				file? response/buffer
				all [
					block? response/headers
					type: select response/headers 'Content-Type
					not find type "html"
				]
			]
		]

		insert-menu: has [buf pos body type][	
			if no-menu? [exit]
			wait .1						;-- give time to the IPC system to write down last log
			if all [
				object? rsp-error
				any [
					26 >= length? response/buffer
					not any [
						find response/buffer "</head>" 
						find response/buffer "<body>"
					]
				]
			][
				append response/buffer default-page
			]
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
						<h2>Redirection Trapped</h2>
						<br><br>Destination URL: }
			append response/buffer rejoin [
				{<a href="} url {">} url
				"</a></center></font></body></html>"
			]
		]

		on-page-start: has [value][
			unless active? [exit]
			unless opts [
				value: select request/config 'debug
				opts: construct/with any [all [block? value value] []] opts-default
			]
			t0: now/time/precise
		]

		on-page-end: has [pos time][
			if no-menu? [exit]
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

		tail-file: func [file [file!] n [integer!] /local p buf sz out][
			unless exists? file [return ""]
			p: tail open/seek file
			sz: 8190
			out: clear any [out make string! sz]	
			until [
				pos: tail buf: copy/part p: skip p negate sz sz
				while [pos: find/reverse pos lf][if zero? n: n - 1 [break]]
				pos: any [pos buf]	
				insert/part tail out pos length? pos
				any [zero? n head? p]
			]
			as-string out
		]

		unprotect 'debug
		set 'debug make debug [
			on: does [
				active?: yes
				on-page-start
			]
			off: does [
				active?: no
			]
			options: func [spec [block!]][
				opts: construct/with spec opts-default
			]
		]
		protect 'debug

		set 'debug? does [active?]
	]

	;--- end of public API ---
	
	lf: #"^/"
	nl: [crlf | cr | lf]
	crlfx2: join crlf crlf
	dquote: #"^""
	
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
	
	decode-msg: func [data /local value list][
		parse load/all data [
			'cfg  set value block! 	 (request/config: value)
			'in	  set value object!	 (request/parsed: value)
			'ip   set value tuple!	 (request/client-ip: value)
			'port set value integer! (request/server-port: value)
			'log  set value file!	 (debug-banner/trace.log: value)
			'session [
				into [
					(session/active?: yes)
					'ID 	 set value string!	(session/id: value)
					'vars 	 set list  block! 	(session/content: list)
					'queries set list  [block! | none!]  (db-cache/sync-list: list)
					'app  	 set value [string! | none!] (request/web-app: value)
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
		request/method: 	 request/parsed/method
		request/posted: 	 request/parsed/content
		request/headers: 	 request/parsed/headers
		request/web-socket?: request/parsed/ws?
		
		request/translated: either request/parsed/script-name [
			request/parsed/file
		][
			join request/config/root-dir [
				request/parsed/path
				request/parsed/target
			]
		]
		if all [
			find request/config 'debug
			not request/web-socket?
		][
			debug-banner/active?: yes
		]
	]
	
	fire-event: func [event [word!] /local fun][
		if all [session/events fun: get in session/events :event][
			protected-exec/event request/parsed/file :fun :event
		]
	]
	
	process-events: has [events ctx init root][	
		either request/web-app [
			root: request/config/root-dir
			either events: select apps root [
				session/events: events
			][
				safe-exec %app-init.r does [init: load join root %/app-init.r]
				repend apps [
					root
					events: make evt-class any [init []]
					ctx: context []
				]
				session/events: events
				change-dir root
				fire-event 'on-application-start
				ctx: third find apps root				 ; ctx needs to reference the new object				
				foreach fun next first events [
					if fun: get in events :fun [bind second :fun ctx]
				]
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
			debug?	(debug?)
			session
		]
		either any [session/active? session/_start?][
			sess: compose/only [
				id	 	(session/id)
				vars 	(session/content)
				queries (db-cache/sync-list)
				timeout (session/timeout)
			]
			if session/_start? [insert sess 'init]
			if session/_close? [append sess 'close]
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
		debug-banner/reset
		session/reset-object
		decode-msg data
		process-events
		decode-params
		locale/decode-lang
		response/reset-object
		clear jobs

		file: request/translated
		if verbose > 0 [log/info ["calling script: " mold file]]
		change-dir first splitted: split-path file
		
		page-events?: all [session/events not request/web-socket?]
		
		debug-banner/on-page-start
		if page-events? [fire-event 'on-page-start]
		
		unless all [
			integer? response/status
			response/status >= 300
		][
			engine/exec file last splitted
		]
		
		if page-events? [fire-event 'on-page-end]
		debug-banner/on-page-end
		
		if verbose > 2 [log/info mold response/buffer]
		debug-banner/insert-menu
		change-dir save-path
		
		compress-output
		
		unless response/buffered? [
			unless empty? response/buffer [response/flush]
			response/flush/end
		]
		request/translated: none	; disables rebinding of webapp scripts
		request/web-app: none		; disables 'do sandboxing (avoid side-effects with other modules)
		result: build-msg
	]
	
	on-quit: has [blk rule p][
		foreach [app-dir events ctx] apps [
			safe-exec %on-application-end events/on-application-end
		]
		
		if all [libs blk: select libs 'on-quit][safe-exec-files blk]
		
		rule: [any [into rule | set p port! (attempt [close p]) | skip]]
		parse databases [some [into rule | skip]]
	]
	
	;--- Initialization ---
	
	file: %httpd.cfg
	all [
		any [
			all [
				value? 'config-path
				any [
					all [slash = last config-path file: config-path/:file]
					file: config-path
				]
				block? cheyenne-conf: load/all file
			]
			all [
				exists? file
				block? cheyenne-conf: load/all file
			]
			all [
				exists?-cache file
				block? cheyenne-conf: load-cache file
			]
		]
		parse cheyenne-conf [
			thru 'globals into [
				any [
					'databases set value block! (
						foreach [name url] value [repend databases/global [name url make block! 1]]
					)
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
	include-file validate locale say do debug?
]
