REBOL []

do-cache uniserve-path/libs/idate.r

install-HTTPd-extension [
	name: 'mod-static
	
	order: [
		method-support	last
		url-translate	first
		url-to-filename	last
		access-check	last
		set-mime-type	last
		make-response	last
		filter-output	last
		reform-headers	last
		logging			last
	]
	
	dot: #"."
	cache-dir: join cheyenne/data-dir %cache/
	log-dir: join cheyenne/data-dir %log/
	log-file: %access.log
	
	max-size: 4 * 1024 * 1024 ; in MB (TBD: export it to the conf file)
	cache: make hash! 100
	cache-size: 0
	
	read-cache: func [req /local file path mdate][
		path: req/in/file
		mdate: req/file-info/date
		either file: find cache path [
			either mdate > third file [
				poke file 3 mdate
				poke file 2 file: read/binary path	
			][
				file: second file
			]
		][
			repend cache [path file: read/binary path mdate]
			cache-size: cache-size + length? file
			if cache-size > max-size [clear cache]	; -- for now, very simple management rule
		]
		file
	]
	
	form-host: func [vhost /local pos][
		if pos: find vhost: form vhost #":" [change pos "-"]
		vhost
	]

	;====== Server events handling ======
	on-started: does [
		unless exists? log-dir [
			make-dir/deep log-dir		; TBD: protect it with 'attempt
		]
		false
	]
	;===================================

	on-quit: does [
		foreach [vhost cache] second second :logging [			;-- flush logs
			unless empty? cache/2 [
				if error? set/any 'err try [
					write/append join log-dir [form-host vhost #"-" log-file] cache/2
				][
					log/error mold disarm :err
				]
			]
		]
	]
	
	method-support: func [req][
		unless find [HEAD GET POST PUT] req/in/method [
			req/out/code: 405
			return true
		]
		none
	]
	
	url-translate: func [req /local list out item path matched e][	
;-- TBD: rewrite this function using only parsing rules
		; --- Interpret /. and /.. directory shortcuts		
		if find path: req/in/path "/." [		
			list: parse path "/"
			while [not tail? list][
				any [
					all [
						any [
							empty? list/1
							list/1 = "."
						]
						remove list
					]
					all [
						list/1 = ".."
						remove list
						any [
							head? list
							remove list: back list
						]
					]
					list: next list			
				]				
			]
			out: make string! 128
			insert out slash
			foreach item head list [
				insert tail out item
				insert tail out slash
			]
			req/in/path: out
			matched: true
		]
		if find path: req/in/path "//" [
			out: make string! 128
			parse/all path [
				any [
					slash any [slash] (insert tail out slash)
					| copy item skip (insert tail out item)
				]
			]			
			req/in/path: out
			matched: true
		]
		if parse req/in/target [some [dot | #"\"] e: to end][
			req/in/target: e
			matched: true
		]		
		if matched [return false]
		none
	]
	
	url-to-filename: func [req /local cfg domain ext][
		cfg: req/cfg
		if find/match req/in/url "/ws-apps" [
			req/out/code: 404		
			return true
		]
		unless req/in/file [	;-- allow other modules to set req/in/file
			; --- Find and assign a default file if necessary		
			if empty? trim req/in/target [		;-- trim should be done when target is parsed
				foreach file to block! any [select cfg 'default []][
					req/in/file: rejoin [cfg/root-dir req/in/path file]				
					if req/file-info: info? req/in/file [
						req/in/target: form file
						if ext: find/last req/in/target dot [
							req/in/ext: to word! ext
							req/handler: select service/handlers req/in/ext
						]
						if req/file-info/type = 'file [return false]
					]
				]
			]
			req/in/file: rejoin [cfg/root-dir req/in/path req/in/target]
		]
		if any [
			not exists? req/in/file
			not req/file-info: info? req/in/file
			req/file-info/type <> 'file
		][	
			either all [
				req/file-info	; a directory exists in the filesystem
				not empty? req/in/target  ; missing / for matching correctly a directory
			][
				req/out/code: 301
				h-store req/out/headers 'Location head insert		; fix: Will, 30/11/2008
					find/match req/in/url join head req/in/path req/in/target
					slash
			][
				req/out/code: 404
			]
			return true
		]
		if all [						;-- test for /foo/bar/ case where 'bar is a file
			req/file-info/type = 'file
			slash = last req/in/url
			not req/in/target
		][
			req/out/code: 404
			return true
		]	
		false
	]

	access-check: func [req /local info mdate][
		; --- Generate the Last-Modified header
		mdate: req/file-info/date
		mdate: to date! rejoin [mdate/date slash mdate/time]
		h-store
			req/out/headers 
			'Last-Modified 
			to-GMT-idate/UTC req/file-info/date: mdate
		false
	]

	set-mime-type: func [req /local ext mime][
		all [
			req/in/file
			ext: find/last/tail req/in/file dot
			ext: to word! to string! ext
		]	
		req/out/mime: either all [ext mime: find service/mime-types ext][
			first find/reverse mime path!
		][
			'application/octet-stream
		]
		false
	]

	make-response: func [req /local since][
		; --- If file not modified => send a 304
		if all [
			since: select req/in/headers 'If-Modified-Since
			req/file-info/date = attempt [to-rebol-date since]
		][
			req/out/code: 304				
			return true
		]
		req/out/code: 200
		either req/file-info/size > 65536 [		;-- for files > 64Kb, stream them from disk
			req/out/content: req/in/file
		][										;-- for files <= 64Kb, send them from memory cache
			req/out/content: read-cache req
		]
		true
	]
	
	filter-output: func [req /local count new][
		either all [
			new: select req/cfg 'on-status-code
			new: select new req/out/code
			req/loops < 4			;-- limit number of forwarding for the same request
		][
			either integer? new [
				req/out/code: new
			][
				req/out/forward: new
			]
			true
		][
			none
		]
	]

	reform-headers: func [req /local cs roh][
		roh: req/out/headers
		if all [
			req/out/mime = 'text/html 
			cs: any [
				select req/cfg 'charset
				select service/conf/globals 'charset
			] 
			not roh/Content-Type
		][
			h-store roh 'Content-Type join "text/html; charset=" cs
		]
		h-store roh 'Date to-GMT-idate/UTC now
		false
	]

	logging: func [req /local data cache out c][
		cache: [default [0:00:01 ""]]

		if any [not req/out/log? find req/cfg 'disable-log][return false]
		
		unless c: select cache req/vhost [
			repend cache [req/vhost c: reduce [0:00:01 make string! 1024]]
		]
		out: second c
		insert tail out service/client/remote-ip
		insert tail out " - "
		insert tail out any [req/auth/user "- "]
		insert tail out to-CLF-idate now
		insert tail out { "}
		insert tail out trim/tail req/in/status-line
		insert tail out {" }
		insert tail out req/out/code
		insert tail out #" "
		insert tail out any [
			all [req/in/method = 'HEAD #"-"]
			all [not zero? req/out/length req/out/length]
			all [
				data: req/out/content
				any [all [file? data req/file-info/size] length? data]
			] 
			#"-"
		]
		insert tail out newline

		data: now
		if data <> first c [
			c/1: data
			if error? set/any 'err try [
				write/append join log-dir [form-host req/vhost #"-" log-file] second c
			][
				log/error mold disarm :err
			]
			clear second c
		]
		false
	]

	words: [
		;--- Define the root directory for a vhost
		root-dir: [file!] in main do [
			if slash = last args/1 [remove back tail args/1]			
		]
		
		;--- Set the maximum data size accepted for POST requests
		post-max: [integer!] in main
		
		;--- Define the maximum size for POSTed data handled in memory
		post-mem-limit: [integer!] in main
		
		;--- Define the default file(s) for a directory
		default: [file! | block!] in [main location folder]
		
		;--- Define the listen port(s)
		listen: [integer! | block!] in globals
		
		;--- Set the log file directory
		log-dir: [file!] in globals do [
			service/mod-list/mod-static/log-dir: first args
		]
		
		;--- Disable HTTP logs output for the domain or webapp
		disable-log: in main
		
		;--- Test if an extension has been loaded and apply the body rules if true
		if-loaded?: [word!] [block!] in globals do [
			if find service/mod-list args/1 [process args/2]
		]
		
		;--- Catch and forward responses based on their status code 
		on-status-code: [block!] in main
		
		;--- Add a new mime-type
		set-mime: [path!] [word! | block!] in globals do [
			use [pos sm][
				if pos: find/only service/mime-types args/1 [
					remove/part pos any [find next pos path! tail pos]
				]
				sm: service/mime-types
				append/only sm args/1
				new-line back tail sm on
				foreach ext to block! args/2 [			
					ext: mold ext
					if dot = first ext [remove ext]
					append sm to word! ext
				]
			]
		]
		
		;--- Define flags for data persistence handling
		persist: [block!] in globals
		
		;--- Associate a file extension with an handler
		bind: [word!] 'to [word! | block!] in globals do [
			foreach ext to-block args/2 [
				repend service/handlers [ext args/1]
			]
		]
		
		;--- Set a given charset globally, per domain or per webapp
		charset: [word!] in [globals main]
		
		;--- Define a set of recurring jobs to do
		jobs: [block!] in globals do [		
			scheduler/plan/new args/1
		]
		
		;--- Force user defined DNS server(s)
		dns-server: [tuple! | block!] in globals
		
		;--- Block incoming connection if matching pattern found on request line
		block: [word! | string! | block!] in globals do [
			use [blk][
				blk: to-block args/1
				service/block-list: make block! length? blk
				foreach s blk [
					if string? s [repend service/block-list [s 0]]
					if s = 'ip-host [service/block-ip-host?: yes]
				]
			]
		]
		
		;--- Allow IP banning
		allow-ip-banning: [opt [time!]] in globals do [
			service/banning?: any [all [time? args/1 args/1] 0:01:00]
		]
		
		;--- User defined incoming folder for uploaded files
		incoming-dir: [file!] in main do [
			if slash <> last args/1 [append args/1 slash]
		]
		
		;--- User defined PID file folder
		pid-dir: [file!] in globals do [
			if slash <> last args/1 [append args/1 slash]
		]
	]
]
