REBOL [
	Title: "UniServe kernel"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Copyright: "@ 2002-2009 SOFTINNOV"
	Email: nr@softinnov.com
	Date: 31/08/2009
	File: %uni-engine.r
	Version: 0.9.35
	Purpose: "Multi-protocol asynchrone client/server framework"
	License: {
		BSD License, read the complete text in %docs/license.txt
		This license covers this source code and all files in this
		archive.
	}
]

unless value? 'uniserve-path  [uniserve-path: what-dir]
if slash = last uniserve-path [remove back tail uniserve-path]

unless value? 'encap-fs  [do uniserve-path/libs/encap-fs.r]
unless value? 'log-class [do-cache uniserve-path/libs/log.r]
unless value? 'parse-url [do-cache uniserve-path/libs/url.r]

either encap? [
	; --- patch for 'in function to accept port! datatype
	if not find select ti: third :in 'object port! [
		clear ti
		append ti [object [object! port!] word [any-word!]]
	]
	launch*: :launch
	; ---
][
	; --- 'launch function rewritten using 'call ---
	if native? :call [
		launch*: func [cmd [string!]][
			call join form to-local-file system/options/boot [" -qws " cmd]
		]
	]

	; --- patch for 'in function to accept port! datatype
	unless find ti: find third :in block! port! [append ti port!]
	; ---
]

uniserve: make log-class [
	name: 'uniserve
	verbose: 0		; > 0 => show debug info

	services:  make block! 20
	protocols: make block! 20
	
	services-path:  %services
	protocols-path: %protocols 

	max-ports: 1000
	ip-buffer: make binary! ip-buf-size: 64 * 1024
	dns-cache: make hash! 100 ; ["domain" 1.2.3.4 hits ...]
	
	spwl: system/ports/wait-list
	flag-stop: off

	plugin-class: context [
		name: port-id: hidden: peer: stop-at: shared: module: events:
		on-received: on-raw-received: set-peer: on-error: auto-expire:
		on-write-done: on-write-chunk: none
		scheme: 'tcp

		write-peer: func [data [binary! string! file!] /with port /local list][
			unless with [port: peer]
			unless find spwl port [
				if verbose > 0 [log/warn "writing aborted: premature connection close"]
				return true
			]
			insert tail port/locals/write-queue :data				
			unless find list: port/async-modes 'write [
				set-modes port head change/only at [async-modes: none] 2 union list [write]
			]
			if in self 'write-server [on-write port]
			if verbose > 4 [log/info ["output =>^/" mold :data]]
			true
		]
		close-peer: func [/force /with port][
			unless with [port: peer]
			port/locals/flag-close: on
			if any [force empty? port/locals/write-queue][
				uniserve/close-connection port
			]
		]
		share: func [spec [block!]][uniserve/shared: make uniserve/shared spec]
	]

	service-class: make plugin-class [
		write-client: :write-peer
		close-client: :close-peer
		set-peer: func [port][client: peer: port]
		on-new-client: on-close-client: client: on-started: none
	]

	protocol-class: make plugin-class [
		write-server: func [data /with port][
			unless with [port: server]
			write-peer/with data port
		]
		close-server: func [/with port][
			unless with [port: server]
			close-peer/with port
		]
		set-peer: func [port][server: peer: port]
		on-init-port: on-close-server: events: service: server: 
		on-connected: on-failed: none
		connect-retries: 10	
	]
	
	touch: func [port /local timeout][
		if all [
			port/locals/expire 
			timeout: port/locals/handler/auto-expire
		][
			port/locals/expire: now + timeout
		]
	]
	
	check-expired: has [res pl][
		remove-each port spwl [
			if res: all [
				port? port
				object? pl: port/locals
				in pl 'expire
				pl/expire
				now > pl/expire
			][
				if verbose > 1 [
					log/info ["Timeout port: " port/remote-ip]
				]
				close-connection/keep port
			]
			res
		]
	]
	
	store-dns: func [domain [string!] ip [tuple!]][
		insert tail dns-cache domain
		insert tail dns-cache ip
		insert tail dns-cache 1
	]
	
	set 'open-port func [
		[catch throw]
		url [url! string!] events [block!] /with vars [block!] 
		/local port proto px-host px-port pos uo host
	][
		flag-stop: off
		forall events [
			if set-word? events/1 [change events to-lit-word events/1]
		]
		uo: parse-url url	
		if uo/scheme = 'dns [
			return open-dns uo/host reduce [uo/scheme head events vars] :on-dns-data
		]
	;--- on-cache...
		port: make port! head insert tail copy [
			scheme: 'tcp
			user: uo/user
			pass: uo/pass
		] any [all [with vars] []]
		port/host: any [
			all [px-host: system/schemes/default/proxy/host px-host] uo/host
		]
		attempt [port/host: to tuple! port/host]
		if px-port: system/schemes/default/proxy/port-id [
			port/port-id: px-port
		]
		port/path: any [uo/path "/"]
		port/target: any [uo/target ""]		
		unless proto: select protocols uo/scheme [
			make error! join "unknown protocol " uo/scheme
		]
		port/locals: reduce [uo/scheme proto/connect-retries]
		port/scheme: proto/scheme
		if any [not port/port-id: uo/port-id zero? port/port-id][
			port/port-id: proto/port-id
		]		
		port/url: url
		proto/on-init-port port url	
		port/state/flags: system/standard/port-flags/pass-thru
		port/state/func: 3				; black magic !			
		port/user-data: head events
		host: port/host
		if pos: find dns-cache port/host [
			change at pos 3 pos/3 + 1
			;port/host: second pos
			host: port/remote-ip: second pos
		]		
		either tuple? host [
			append spwl port
			if verbose > 1 [log/info reform ["Connecting to" port/host ":" port/port-id]]
			port/async-modes: 'connect
			port/awake: :on-connect
			port/awake port		; try to connect at once			
		][
			open-dns host port :on-resolve
		]
		port
	]

	set 'insert-port func [port data /custom blk [block!] /local name][
		either in port/locals/handler name: 'new-insert-port [
			fire-event/arg/arg2/arg3 port name port data blk
		][
			port/locals/handler/write-peer/with data port
		]
	]
	
	set 'reopen-port func [port /no-close /local events proto uo][
		flag-stop: off
		events: port/locals/evt-saved
		;if not no-close [close-port port]
		;close-connection/bypass port
		;remove find spwl port
		uo: parse-url port/url
		proto: select protocols uo/scheme	
		port/locals: reduce [uo/scheme proto/connect-retries]
		proto/on-init-port port port/url
		port/state/flags: system/standard/port-flags/pass-thru
		port/state/func: 3				; black magic !			
		port/user-data: events
		if not find spwl port [append spwl port]
		if verbose > 1 [log/info reform ["Reconnecting to" port/host ":" port/port-id]]
		port/async-modes: 'connect
		port/awake: :on-connect
		port/awake port		; try to connect at once
		port
	]
	
	set 'closed-port? func [port][all [port/state not zero? port/state/flags and 1024]]

	set 'close-port func [port][
		either all [
			object? port/locals
			in port/locals 'handler
		][
			port/locals/handler/close-peer/with port
		][
			uniserve/close-connection port
		]
	]
	
	open-service: func [name [word!] id /local model svr][
		flag-stop: off
		either model: select services name [
			if error? try [
				append spwl svr: open/binary/direct/no-wait
					make port! compose [
						scheme: (to-lit-word model/scheme)
						server-type: (model)
						port-id: (any [id model/port-id])
						either scheme = 'udp [
							init-connection/service self self
							async-modes: [read]
							awake: :on-data
						][
							async-modes: 'accept
							awake: :on-accept
						]
					]
				;if model/scheme = 'tcp [set-modes svr [no-delay: on]]
			][
				log/error [
					"cannot open server " mold name " on port "
					any [id model/port-id]
				]
				return none
			]
		][
			log/error ["service " mold name " not installed!"]
			return none
		]
		true
	]

	find-service: func [name id /local list port][
	 	list: spwl
		forall list [
			if all [
				port? port: list/1
				in port 'server-type
				port/server-type/name = name
				port/port-id = any [id port/server-type/port-id]
			][
				return list
			]
		]
		false
	]
	
	close-service: func [name id /local pos][
		either pos: find-service name id [
			close pos/1
			remove pos
		][
			log/warn [mold name " not running!"]
			none
		]
	]
	
	init-connection: func [
		new /service server 
		/local proto evt list len names i fun evt-handler
	][
		;if new/scheme = 'tcp [set-modes new [no-delay: on]]
		evt-handler: any [
			all [service server/server-type]
			proto: select protocols new/locals/1
		]
		new/locals: context [
			handler: :evt-handler 
			write-queue: copy []
			file-chunk: 64 * 1024
			stop: handler/stop-at
			in-buffer: make binary! 64 * 1024
			start-time: now
			expire: all [
				evt-handler/auto-expire
				start-time + evt-handler/auto-expire
			]
			file: flag-close: events: evt-saved: none
		]
		if proto [
			evt: reduce new/locals/evt-saved: new/user-data
			list: array len: length? names: new/locals/handler/events
			i: 1
			until [
				if fun: select evt pick names i [poke list i :fun]
				len < i: i + 1
			]
			new/locals/events: list
		]
		check-expired
	]

	close-connection: func [port /bypass /keep /local ctx res][
		res: false
		if all [
			not bypass
			object? port/locals
			in port/locals 'handler
		][
			ctx: port/locals/handler
			res: fire-event port any [
				in ctx 'on-close-client
				in ctx 'on-close-server
			]
		]
		either port/async-modes = 'connect [
			if verbose > 0 [log/info ["port reconnecting : " port/remote-ip]]
		][
			unless keep [remove find spwl port]
			attempt [close port]
			;port/awake: none		; -- used as a marker for a closed port
			if verbose > 0 [log/info ["port closed : " port/remote-ip]]
		]
		res
	]

	remove-from-queue: func [list][
		if port? first list [close first list]
		remove list
	]
	
	close-file-port: func [pl][	
		if pos: find pl/write-queue port! [close pos/1]
		clear pl/write-queue
	]

	fire-event: func [port name /init /arg v /arg2 v2 /arg3 v3 /local ctx pl err log-err][
		if verbose > 1 [
			log/info rejoin [
				"calling >" name "<" any [
					all [
						arg 
						series? v
						join " with " mold to-string copy/part v 50
					] ""
				]
			]
		]
		log-err: [
			log/error rejoin [name " call failed with error: " mold err: disarm err]
			close-connection/bypass port 
		]
		either init [
			if error? set/any 'err try [
				catch/name [do select reduce port/user-data :name port v v2 v3 none] 'uniserve
			] log-err
		][
			pl: port/locals
			ctx: pl/handler
			ctx/stop-at: pl/stop	
			if ctx/events [set ctx/events pl/events]
			ctx/set-peer port		
			if error? set/any 'err try [
				catch/name [ctx/:name v v2 v3 none] 'uniserve
			] log-err
			pl/stop: ctx/stop-at
		]
		if :err = 'stop-events [
			if value? 'scheduler [scheduler/flag-exit: on]
			flag-stop: on
		]
	]
	
	open-dns: func [host local-ctx callback /local dns][
		dns: open/no-wait [
			scheme: 'dns
			host: "/async"
			locals: local-ctx
			awake: :callback
		]
		append spwl dns
		insert dns host
		dns
	]
	
	set 'stop-events does [throw/name 'stop-events 'uniserve]
	
	;--- Async I/O handlers ---
	
	would-block?: func [err-obj][err-obj/code = 517]
	
	process-error: func [port err phase /local action][
		either action: select [
			501 [
				if all [phase = 'write verbose > 0][
					log/warn "write failed: client port closed"
				]
				close-connection port
			]
			517	[]		;-- blocking operation, just let go.
		] err/code [
			do action
		][
			log/error reform ["Async" phase "phase failed:" err/code]
		]
	]

	on-dns-data: func [dns /local result ctx][
		result: copy dns
		close dns
		remove find spwl dns
		ctx: context append copy [
			locals: context [
				handler: select protocols dns/locals/1
				stop: none			
				events: extract/index reduce dns/locals/2 2 2
				event-names: bind [on-resolved] in handler 'self
			]
			user-data: none
		] any [dns/locals/3 []]
		
		fire-event/arg ctx 'on-received result
		flag-stop
	]
	
	on-resolve: func [dns /local port][
		port: dns/locals
		port/remote-ip: copy dns
		close dns
		remove find spwl dns
		either port/remote-ip [
			append spwl port
			if verbose > 1 [log/info reform ["Connecting to" port/host ":" port/port-id]]
			port/async-modes: 'connect
			port/awake: :on-connect
			port/awake port		; try to connect at once
			store-dns port/host port/remote-ip
		][
			if verbose > 1 [log/info join "Unknown host: " port/host]
			fire-event/init/arg port 'on-error 'unknown-host
		]
		flag-stop
	]
	
	on-connect: func [port /local err res][
		either error? err: try [
			port: open/direct/binary/no-wait port
		][
			either would-block? disarm err [
				if verbose > 2 [
					log/info "opening connection failed...retrying"
				]
				port/locals/2: port/locals/2 - 1
				if zero? port/locals/2 [			
					if verbose > 1 [log/info "Host not responding!"]
					remove find spwl port
					fire-event/init/arg port 'on-error 'connect-failed
				]
			][
				if verbose > 1 [log/info "Host unreachable!"]
				fire-event/init/arg port 'on-error 'unreachable
			]
			flag-stop
		][
			if verbose > 1 [
				log/info reform ["Connected to" port/remote-ip "port:" port/remote-port]
			]
			init-connection port
			fire-event port 'on-connected
			port/async-modes: [write]		; 'read is unsafe here 
			port/awake: :on-data			; because 'awake is directly called
			on-data port
		]
	]

	on-accept: func [server-port /local err new handler][
		either error? err: try [
			new: first server-port 
		][
			process-error server-port disarm err 'accept
			false
		][
			insert tail spwl new
			if verbose > 0 [
				log/info ["new client: " new/remote-ip " - " server-port/port-id]
			]
			new/async-modes: [read write]
			new/awake: :on-data
			init-connection/service new server-port
			fire-event new 'on-new-client
			flag-stop
		]
	]

	on-data: func [port][
		unless port/locals/flag-close [
			either find port/async-modes 'read [
				on-read port
				if block? port/locals [return flag-stop]	; avoid 'write action on opening port
			][
				insert port/async-modes 'read
			]
		]		
		either empty? port/locals/write-queue [		
			remove find port/async-modes 'write
		][
			on-write port
		]	
		flag-stop
	]
	
	on-read: func [port /local in-buf pl state cut][
		clear ip-buffer
		either error? state: try [
			either port/scheme = 'udp [		; UDP's 'read-io support is not reliable
				either state: copy port [
					insert tail ip-buffer state		; use a local word to avoid this transfer
					length? state
				][0]
			][
				read-io port ip-buffer ip-buf-size
			]
		][
			process-error port disarm state 'read
		][			
			either all [port/scheme <> 'udp state <= 0][
				if verbose > 0 [log/info ["Connection closed by peer " port/remote-ip]]
				close-connection port
			][
				touch port
				if verbose > 1 [log/info [">> Port: " port/port-id ", low-level reading: " state]]
				pl: port/locals
				in-buf: pl/in-buffer
				insert tail in-buf ip-buffer
				either pl/stop [
					while [
						any [
							all [
								integer? pl/stop
								pl/stop <= length? in-buf
								cut: pl/stop
							]
							all [
								any [string? pl/stop char? pl/stop]
								cut: find/tail in-buf pl/stop
							]
						]
					][
						fire-event/arg port 'on-received copy/part in-buf cut
						remove/part in-buf cut
					]
					unless any [pl/stop empty? in-buf][
						fire-event/arg port 'on-raw-received in-buf
						clear in-buf
					]
				][
					fire-event/arg port 'on-raw-received in-buf
					clear in-buf
				]
			]
		]
	]
	
	on-write: func [port /local pl state len q list data][	
		pl: port/locals
		q: pl/write-queue 
		unless find list: port/async-modes 'write [
			set-modes port head change/only at [async-modes: none] 2 union list [write]
		]
		if file? q/1 [
			change q data: open/read/binary/direct first q
			either data: copy/part data pl/file-chunk [
				fire-event/arg port 'on-write-chunk data
				insert q data
			][
				log/error "cannot read file : file empty ? Emission cancelled"
				remove-from-queue q
			]
		]
		either error? state: try [
			write-io port copy first q len: length? first q
		][
			process-error port disarm state 'write
		][		
			either all [port/scheme <> 'udp state = -1][
				if verbose > 0 [log/info ["Connection closed by peer " port/remote-ip]]
				close-connection port
				close-file-port pl
			][
				touch port
				if verbose > 1 [log/info ["<< Port: " port/port-id ", low-level writing: " state]]				
				either state < -1 [
					if verbose > 0 [log/warn ["write error code " state]]
					close-connection port
					close-file-port pl
				][
					change q copy skip first q state
					if tail? first q [
						remove-from-queue q
						if port? q/1 [
							either data: copy/part first q pl/file-chunk [
								insert q data
							][
								remove-from-queue q
							]
						]
						if all [pl/flag-close tail? q][
							close-connection port
						]
					]
				]
				fire-event/arg/arg2 port 'on-write-done state pl/write-queue
				if empty? pl/write-queue [
					remove find port/async-modes 'write
				]
			]
		]
	]
	
	control: func [
		/start /stop /list /shutdown
		/install 
			file 
		/only 
			name [word!] id [integer! none!] 
		/local svc p out fun exec init
	][
		if start [
			exec: [
				log/info ["starting " mold name "..."]
				unless find-service name id [
					out: open-service name any [id svc/port-id]
				]			
				if out [
					if function? get fun: in svc 'on-started [
						if verbose > 0 [log/info ["Calling >on-started< in " mold name]]
						do :fun						
					]
				]
			]
			either only [
				unless svc: select services name [return false]
				do exec
				return to-logic out
			][
				foreach [name svc] services exec
			]
		]
		if stop [return to-logic close-service name id]
		if list [
			out: make block! 32
			foreach [name svc] services [
				unless find-service name svc/port-id [
					repend out [svc/port-id name svc/module no]
				]
			]
			foreach p spwl [
				if system/words/all [port? p in p 'server-type][
					repend out [
						p/port-id
						p/server-type/name
						p/server-type/module
						yes
					]
				]
			]
			return out
		]
		if shutdown [
			remove-each p spwl [
				all [port? p in p 'server-type do [attempt [close p] true]]
			]
		]
		true
	]
	
	boot: func [
		/no-wait	
		/no-loop	; DEPRECATED: use /no-wait instead
		/no-start	; disable auto service starting
		/with spec [block!]
		/local name svc init
	][
		flag-stop: off
		path: uniserve-path/:services-path	
		if exists? path [
			foreach file read path/. [
				if script? svc: path/:file [
					either with [
						name: to-word to-string copy/part file find file #"."						
						if all [find spec 'services find spec/services name][do svc]
					][do svc]
				]
			]
		]
		path: uniserve-path/:protocols-path
		if exists? path [
			foreach file read path/. [
				if script? svc: path/:file [
					either with [
						name: to-word to-string copy/part file find file #"."
						if all [find spec 'protocols find spec/protocols name][do svc]
					][do svc]
				]
			]
		]
		foreach [name svc] services [
			svc/shared: uniserve/shared		;-- check issues with reference to shared object!
			if all [init: in svc 'on-load function? get init][			
				if verbose > 0 [log/info ["Calling >on-load< in " mold name]]
				do :init
			]
		]
		unless no-start [control/start]
		unless any [no-loop no-wait][wait []]
	]

	install-plugin: func [
		body [block!]
		/as-service
		/local new pos class callback list
	][
		set [class callback list] reduce any [
			all [as-service [service-class 'on-new-client services]]
			[protocol-class 'on-connected protocols]
		]
		new: make log-class []
		new: make class new
		new: make new body

		either any [
			get in new 'on-received
			all [not new/stop-at get in new 'on-raw-received]
			all [not new/stop-at get in new callback]
		][	
			either pos: find list new/name [
				change pos/2 new
			][
				repend list [new/name new]
			]
		][
			log/error rejoin ["no valid receive callback in " mold new/name ":" new/port-id]
		]
		new
	]

	set 'install-service  func [body][install-plugin/as-service body]
	
	set 'install-protocol func [body /local plugin new evt evt-names name value][
		foreach evt evt-names: select body to-set-word 'events [
			append body to-set-word evt
		]
		append body none
		plugin: install-plugin body
		log/info ["Async Protocol " mold plugin/name " loaded"]
	]
	
	shared: context [control: none]
	shared/control: :control
]

protect [
	open-port
	insert-port
	close-port
	reopen-port
	closed-port?
	stop-events
	install-service
	install-protocol
]

system/options/quiet: true
