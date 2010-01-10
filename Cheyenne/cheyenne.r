REBOL [
	Title: "Cheyenne Web Server"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Purpose: "Full-featured Web Server"
	Encap: [quiet secure none title "Cheyenne" no-window] 
	Version: 0.9.20
	Date: 08/03/2009
]

; === Setting up the runtime context ===

system/network/host: does [system/network/host: read dns://]
system/network/host-address: does [
	system/network/host-address: read join dns:// system/network/host
]

#include %encap-paths.r

uniserve-path: %../UniServe/
modules-path: %handlers/

#include %../UniServe/libs/encap-fs.r
unless value? 'encap-fs [do uniserve-path/libs/encap-fs.r]
#include %.cache.efs

set-cache [
	%HTTPd.r
	%httpd.cfg
	%misc/ [
		%conf-parser.r
		%debug-head.html
		%debug-menu.rsp
		%mime.types
		%system.r
		%os.r
		%service.dll
		%win32.r
		%unix.r
		%macosx.r
		%admin.r
	]
	%mods/ [
		%mod-action.r
		%mod-alias.r
		%mod-fastcgi.r
		%mod-rsp.r
		%mod-ssi.r
		%mod-static.r
		%mod-userdir.r
		%mod-internal.r
		%mod-extapp.r
		%mod-socket.r
		%mod-upload.r
	]
	%handlers/ [
		%CGI.r
		%RSP.r
	]
	%internal/ [
		%about.rsp
		%backgroundbottom.gif
		%backgroundmiddle.gif
		%backgroundtop.gif
		%bullet.gif
		%cheyenne.png
		%default.css
		%rebol.gif
		%si.png
	]
	uniserve-path [
		%uni-engine.r
		%libs/ [
			%headers.r
			%log.r
			%html.r
			%decode-cgi.r
			%idate.r
			%cookies.r
			%url.r
			%scheduler.r
			%email.r
		]
		%services/ [
			%logger.r
			%MTA.r
			%RConsole.r
			%task-master.r
			%task-master/ [
				%task-handler.r
			]
		]
		%protocols/ [
			%FastCGI.r
			%SMTP.r
			%DNS.r
			%dig.r
		]
	]
]

do-cache uniserve-path/libs/log.r

; === Patched functions ====

set 'info? func [
    "Returns information about a file or url."
    [catch]
    target [file! url!]
][
    throw-on-error [
        target: make port! target
        query target
    ]
    either none? target/status [
        none
    ] [
        make object! [
            size: target/size 
            date: target/date
            type: any [
            	all [target/status = 'directory 'directory]
            	target/scheme
            ]
        ]
    ]
]

; === Applications launcher ===

cheyenne: make log-class [
	name: 'boot
	verbose: 0
	
	value: evt: port-id: none
	data-dir: system/options/path
	pid-file: %/tmp/cheyenne.pid
	
	sub-args: ""
	args: []
	flags: []
	set-flag: func [w][any [find flags w append flags w]]
	flag?: func [w][to logic! find flags w]
	flags?: func [b][equal? length? b length? intersect flags b]
	propagate: func [arg][append sub-args arg]
	
	set 'OS-Windows? system/version/4 = 3
	
	unless value? 'do-events [set 'do-events does [wait []]]
		
	within: func [obj [object! port!] body [block!]][
		do bind body in obj 'self
	]
	
	do-cheyenne-app: has [vlevel service? home verbosity offset n list][	
		if flag? 'custom-port [port-id: args/port-id]
		if flag? 'verbose [verbosity: verbose: args/verbosity]
		verbosity: any [verbosity 0]
		
		do-cache uniserve-path/libs/scheduler.r
		do-cache uniserve-path/uni-engine.r
		
		log-install 'scheduler			;--	install UniServe's logging in scheduler lib
		scheduler/verbose: verbosity

		if service?: all [OS-Windows? flag? 'service][
			launch-service				;-- launch service thread
			do-cache %misc/admin.r
		]
		do-cache %misc/system.r		;-- install system port and tray icon support for Windows

		do-cache uniserve-path/services/task-master.r		
		do-cache uniserve-path/services/RConsole.r	
		do-cache uniserve-path/services/logger.r
		do-cache uniserve-path/services/MTA.r
		do-cache uniserve-path/protocols/FastCGI.r
		do-cache %HTTPd.r

		within uniserve [
			set-verbose verbosity
			
			shared/pool-start: 	any [all [flag? 'debug 1] all [flag? 'workers args/workers] 4]
			shared/pool-max: 	any [all [flag? 'debug 0] all [flag? 'workers args/workers] 8]
			shared/job-max: 	1000	;-- CGI/RSP requests queue size

			boot/with/no-wait/no-start [] ; empty block avoids loading modules from disk
			
			all [
				not port-id
				port-id: select services/httpd/conf/globals 'listen
				port-id: to-block port-id
			]			
			if port-id [
				;-- ensure that pid filename won't collide with other instances
				insert find/reverse tail pid-file #"." join "-" port-id/1

				;-- relocate non-HTTPd listen ports to allow several instances to run				
				offset: port-id/1 // 63516 + 2020
				in-use: list-listen-ports			
				list: make block! 8
				foreach svc [task-master RConsole logger MTA][
					n: services/:svc/port-id + offset
					until [not find in-use n: n + 1]
					services/:svc/port-id: n
					repend list [svc n]
				]
				log/info ["servers port relocated: ^/" mold new-line/all/skip copy list on 2]
			]
			share [server-ports: list]
			
			if not OS-Windows? [attempt [write pid-file process-id?]]

			control/start/only 'RConsole none
			control/start/only 'Logger none
			if service? [control/start/only 'admin none]

			share [dns-server: select services/httpd/conf/globals 'dns-server]

			do-cache uniserve-path/protocols/SMTP.r
			do-cache uniserve-path/protocols/DNS.r
			do-cache uniserve-path/protocols/dig.r
			
			set-verbose verbosity			;-- for SMTP and dig protocols
			verbose: max verbosity - 2 0	;-- lower down UniServe's and Task-Master's verbosity 
			uniserve/services/task-master/verbose: max verbosity - 1 0
			
			if OS-Windows? [
				if not service? [
					set-tray-help-msg rejoin [
						"Cheyenne is listening on port"
						either all [port-id 1 < length? port-id]["s"][""] ": " 
						replace/all mold/only any [port-id 80] " " ","
					]
				]
			]
			open-system-events
			control/start/only 'MTA none
			foreach p any [port-id [80]][control/start/only 'HTTPd p]
			control/start/only 'task-master none
		]
		if flag? 'embed [exit]
		
		until [
			evt: wait []							;-- main event loop
			either none? evt [
				scheduler/on-timer					;-- scheduler job event
			][
				unless uniserve/flag-stop [log/warn "premature exit from event loop"]
			]
			uniserve/flag-stop
		]
		if verbose > 0 [log/info "exit from event loop"]
		halt
	]
	
	do-bg-process-app: does [
		do-cache uniserve-path/services/task-master/task-handler.r
		ctx-task-class/connect
	]
	
	do-tray-app: does [
		do-cache %misc/system.r
		open-system-events
		set-tray-remote-events
		do-events
	]
	
	do-uninstall-app: does [
		if NT-service? [
			if NT-service-running? [control-service/stop]
			uninstall-NT-service
		]
	]
	
	set-working-folders: has [home][
		home: dirize first split-path system/options/boot
		change-dir system/options/home: system/options/path: home
		OS-change-dir home
		data-dir: either flag? 'folder [args/folder][home]
		if any [
			flag? 'user-desktop
			all [
				not flag? 'service
				data-dir = OS-get-dir 'desktop
			]
		][
			set-flag 'user-desktop
			data-dir: join OS-get-dir 'all-users %Cheyenne/
			make-dir/deep data-dir
		]
	]
		
	parse-cmd-line: has [ssa digit value][
		digit: charset [#"0" - #"9"]
		if ssa: system/script/args [
			parse ssa [
				any [
					"task-handler" (set-flag 'bg-process) break 
					| "-p" copy value any [1 5 digit opt #","] (
						repend args [
							'port-id
							to-block replace/all value "," " "
						]
						set-flag 'custom-port
					)
					| "-fromdesk" (set-flag 'user-desktop)	; -- internal use only
					| "-f" copy value [to " " | to end](
						set-flag 'folder 
						repend args ['folder load trim value]
						propagate reduce [" -f " value]
					)
					| "-e" 		(set-flag 'embed)
					| "-s" 		(set-flag 'service)			; -- internal use only
					| "-u"		(set-flag 'uninstall)				
					| "-w" copy value integer! (
						value: load trim value
						set-flag 'workers
						if zero? value [set-flag 'debug]
						repend args ['workers abs value]
					)			
					| #"-" copy value 1 5 #"v" (
						value: trim value
						set-flag 'verbose repend args ['verbosity length? value]
						propagate join " -" value
					)
					| skip
				]
			]
		]
	]

	boot: has [err][
		if any [
			all [
				encap?
				find system/script/header/encap 'no-window 
			]
			all [
				not encap?
				1 = (system/options/boot-flags and 1) ; -- test -w flag
			]
		][
			set-flag 'no-screen
		]
		
		parse-cmd-line
		
		unless flag? 'bg-process [do-cache %misc/os.r]	; -- can't use any OS calls before that
			
		logger/level: either flag? 'verbose [
			logger/level: either flag? 'no-screen [
				logger/file.log: join %chey-pid- [process-id? %.log]
				'file
			][
				'screen
			]
		][
			none
		]
		
		unless flag? 'bg-process [
			if OS-Windows? [
				if encap? [
					set-working-folders
					insert logger/file.log data-dir
				]
				if all [NT-service? not flag? 'service][set-flag 'tray-only]
			]
			if verbose > 0 [			
				log/info ["cmdline args : " system/script/args]
				log/info ["processed    : " mold args]
				log/info ["boot flags   : " mold flags]
				log/info ["data folder  : " mold data-dir]
			]
		]

		; --- applications dispatcher ---
		if error? set/any 'err try [
			case [
				flag? 'bg-process	[do-bg-process-app]
				flag? 'uninstall	[do-uninstall-app]
				flag? 'tray-only	[do-tray-app]
				true 				[do-cheyenne-app]
			]
		][
			either flag? 'no-screen [
				write/append %crash.log reform [now ":" mold disarm err]
			][
				if value? 's-print [print: :s-print]
				print mold disarm err
				halt
			]
		]
	]
	
	on-quit: does [
		uniserve/services/mta/on-quit					; TBD: manage on-quit events from uni-engine
		if not OS-Windows? [attempt [delete pid-file]]
	]
]

cheyenne/boot
