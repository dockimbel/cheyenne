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

	set-process-to: func [user [string! integer!] group [string! integer!] /local uid gid][
		set [uid gid] reduce [user group]
		if any [string? user string? group][
			either user = group [
				set [uid gid] get-id user
			][
				if string? user  [uid: first get-id user]
				if string? group [gid: second get-id/group group]
			]
		]
		;-- change group id first to inherit privileges from group first
		if not zero? setgid gid [log/error "setgid failed!"]
		if not zero? setuid uid [log/error "setuid failed!"]
	]
	
	words: [
		user:  [string! | integer!] in globals do [user: args/1]
		group: [string! | integer!] in globals do [group: args/1]
	]
]