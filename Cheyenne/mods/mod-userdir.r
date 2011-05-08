REBOL [
	History: {
		08/09/2010 - Applied Kaj's big patch 
		24/09/2010 - Code refactored and simplified
	}
]

install-HTTPd-extension [
	name: 'mod-userdir
	
	order: none
	user: group: none
	col: #":"
	
	on-started: does [
		if all [user system/version/4 <> 3][		;-- exclude Windows
			set-process-to user any [group user]
		]
	]
	on-reloaded: does [
		user: group: none
	]
	
	try-chown: func [file [file!] uid gid][
		unless zero? chown to-local-file file uid gid [
			log/error ["chown " uid ":" gid " " file " failed!"]
		]
	]
	
	get-id: func [name [string!] /group /local file rule uid gid][
		set [file rule] pick [
			[%/etc/group  []]
			[%/etc/passwd [copy uid to col skip]]	
		] to-logic group

		unless exists? file [log/error reform ["accessing" file "failed"]]
		parse/case/all read file [
			some [name col thru col rule copy gid to col break | thru newline]
		]
		unless any [[group gid] all [uid gid]][log/error reform ["id not found in" file]]
		reduce [to-integer uid to-integer gid]
	]

	set-process-to: func [user [string! integer!] group [string! integer!] /local uid gid file][
		set [uid gid] reduce [user group]
		if any [string? user string? group][
			either user = group [
				set [uid gid] get-id user
			][
				if string? user  [uid: first get-id user]
				if string? group [gid: second get-id/group group]
			]
		]
		if all [not zero? uid not zero? gid][
			;-- %trace.log
			if exists? file: uniserve/services/logger/trace-file [try-chown file uid gid]
			;-- %.rsp-sessions
			if all [
				find service/mod-list 'mod-rsp
				exists? file: service/mod-list/mod-rsp/sessions/ctx-file 
			][try-chown file uid gid]
			
			file: uniserve/services/MTA/q-file		;-- %.mta-queue
			if cheyenne/port-id [append copy file join "-" cheyenne/port-id/1]
			if exists? file [try-chown file uid gid]
		]
		;-- change group id first to inherit privileges from group first
		if any [zero? gid not zero? set-gid gid][log/error ["setgid '" group " failed!"]]
		if any [zero? uid not zero? set-uid uid][log/error ["setuid '" user " failed!"]]
	]
	
	words: [
		user:  [string! | integer!] in globals do [user: args/1]
		group: [string! | integer!] in globals do [group: args/1]
	]
]