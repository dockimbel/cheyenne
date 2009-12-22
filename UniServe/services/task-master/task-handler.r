REBOL [
	Title: "Uniserve: task-master client"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Version: 1.2.0
	Date: 31/12/2008
]

logger: context [
	server: make system/standard/port [
		scheme: 'tcp
		port-id: 9802
		host: 127.0.0.1
	]
	col: #":"
	zero: #"0"
	dot: #"."
	excl: #"!"
	dash: #"-"

	emit: func [data err? /local h time off][
		time: mold now/time/precise
		off: pick [-3 -6] system/version/4 = 3
		if col = time/2 [insert time zero]
		if dot = pick tail time off [insert tail time zero]
		if not find time dot [
			insert tail time pick [".000" ".000000"] system/version/4 = 3
		]
		data: rejoin [now/day slash now/month dash time dash data newline]
		h: debase/base to-hex length? data 16
		insert tail h #"T" ;pick [#"E" #"T"] to logic! err? 
		insert data h
		attempt [write/direct/no-wait/binary server data]
	]

	notify: func [msg module [word!] type [word!] /local out][
		out: either block? msg [rejoin msg][copy msg]
		if not string? out [out: mold out]
		uppercase/part out 1
		out: reform switch type [
			warn  [["# Warning in" mold reduce [module] col out excl]]
			error [["## Error in"  mold reduce [module] col out excl]]
			fatal [["### FATAL in" mold reduce [module] col out excl]]
			info  [[mold reduce [module] out]]
		]
		emit out type <> 'info
	]
]

log-class: context [
	name: 'log-class

	log: func [[throw] msg /warn /error /info /fatal][
		case [
			info  [logger/notify msg name 'info]
			warn  [logger/notify msg name 'warn]
			error [logger/notify msg name 'error]
			fatal [logger/notify msg name 'fatal]
		]
	]
]

debug: context [
	server: none	;-- reserved for remote console future use
	
	emit-dbg: func [msg][logger/emit join "[DEBUG] " msg false]
	
	set '? print: func [msg][emit-dbg msg :msg]
	
	probe: func [msg][emit-dbg mold :msg :msg]
	
	set '?? func ['name][
		emit-dbg either word? :name [
			head insert tail form name reduce [": " mold name: get name]
		][
			mold :name
		] false
	]
	
	trace: func [n [integer!]][
		;-- TBD
	]
]

protect [logger log-class debug]

if ssa: system/script/args [
	ssa: load/all ssa
	uniserve-path: select ssa 'u-path
	modules-path:  select ssa 'm-path
	servers-port:  select ssa 's-port
	
	either block? servers-port [
		uniserve-port: servers-port/task-master
		logger/server/port-id: servers-port/logger
	][
		uniserve-port: servers-port
	]
]
if not value? 'uniserve-path [uniserve-path: what-dir]
if not value? 'modules-path  [modules-path: dirize uniserve-path/modules]
if not value? 'uniserve-port [uniserve-port: 9799]

change-dir system/options/path

unless value? 'encap-fs [
	do uniserve-path/libs/encap-fs.r
	change-dir system/options/path
]

s-read-io: get in system/words 'read-io
s-quit:    get in system/words 'quit
s-halt:    get in system/words 'halt

ctx-task-class: make log-class [
	name: 'task-handler
	verbose: 0
	
	module: server: scheme: state: err: req: t0: len: remains: none
	packet: make binary! buf-size: 1024 * 16
	request: make binary! buf-size
	
	server-address: 127.0.0.1
	server-port: uniserve-port
	
	modules: make block! 5
	
	set 'install-module func [body [block!]][
		module: make make log-class [on-task-received: result: none] body
		if verbose > 0 [log/info ["installing module : " mold module/name]]
		repend modules [module/name module]
		recycle
	]

	set 'server-send-data func [data][
		insert data debase/base to-hex length? data 16
		insert server data
	]

	connect: does [
		server: open/binary/direct rejoin [tcp:// server-address ":" server-port]
		set-modes server [keep-alive: on]
		wait [server 0]		; fix for first packet read error rare case (state = -4)
		
		name: to-word rejoin [mold name #"-" form server/local-port]
		if verbose > 0 [log/info "connected to Uniserve"]
		
		forever [
			clear request
			clear packet
			if verbose > 0 [log/info "waiting for task..."]
			wait server
			state: s-read-io server packet 4
			case [
				state <= 0 [
					if state < -1 [
						log/error join "quit - cause: server read state is " state
					]
					attempt [close server]
					s-quit					
				]
				state = 4 [
					remains: len: to integer! packet
				]
				state < 4 [
					len: to integer! copy/part packet 4
					remains: len - length? packet: at packet 5
					insert tail request packet
				]
			]
			if verbose > 0 [log/info ["header received, body:" len]]
			until [
				clear packet
				wait server
				state: s-read-io server packet min remains buf-size			
				if verbose > 1 [log/info ["state:" state]]
				if positive? state [
					remains: remains - length? packet
					insert tail request packet
				]
				any [zero? remains state <= 0]
			]
			if verbose > 0 [t0: now/time/precise]
			req: load as-string request
			either error? set/any 'err try [
				if not find modules req/2 [
					do-cache join modules-path [req/2 %.r]
					change-dir system/options/path
				]
				module: select modules req/2
				module/result: none
				module/on-task-received load as-string req/3
				false
			][		
				err: disarm err				
				log/error mold err
				server-send-data remold ['error mold/all err]
			][
				server-send-data remold ['ok module/result]
				if verbose > 0 [log/info ["done in " now/time/precise - t0 " sec"]]
			]
		]
	]
]

if error? set/any 'err try [
	if not encap-fs/cache [ctx-task-class/connect]
][
	attempt [close ctx-task-class/server]
	change-dir system/options/path
	write/append %worker-crash.log reform [newline now ":" mold disarm :err]
]
