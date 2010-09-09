REBOL [
	History: {
		08/09/2010 - Applied Kaj's big patch 
	}
]

install-HTTPd-extension [
	name: 'mod-userdir
	
	order: none
	lf: #"^/"
	col: #":"
	
	boot-code: []
	
	on-started: does [do boot-code]
	on-reload:  does [clear boot-code]
	
	get-ugid: func [name [string!] /local file line uid gid][
		unless attempt [file: read/lines %/etc/passwd][
			log/error "accessing /etc/passwd failed"
			return none
		]
		foreach line file [
			if all [line: find/case/match line name  col = first line][
				return either parse/all next line [
					thru col
					copy uid to col skip
					copy gid to col
					to end
				][
					reduce [to-integer uid to-integer gid]
				][
					log/error "invalid format reading /etc/passwd !"
					none
				]
			]
		]
		log/error "user not found in /etc/passwd"
		none
	]
	
	get-gid: func [name [string!] /local file line gid][
		unless attempt [file: read/lines %/etc/group][
			log/error "accessing /etc/group failed"
			return none
		]
		foreach line file [
			if all [line: find/case/match line name  col = first line][
				return either parse/all next line [
					thru col
					copy gid to col
					to end
				][
					to-integer gid
				][
					log/error "invalid format reading /etc/group !"
					none
				]
			]
		]
		log/error "group not found in /etc/group"
		none
	]
	
	change-id: func [id [string! integer!] /user /group /local gid][
		either string? id [
			unless id: get-ugid id [return none]
			set [id gid] id
		][
			gid: id
		]
		if group [setgid gid]
		if user [
			;logger/file.log: join logger/file ["-" id %.log]
			setuid id
		]
	]
	
	change-gid: func [id [string! integer!]][
		if string? id [
			unless id: get-gid id [return none]
		]
		setgid id
	]
	
	words: [
		user: [string! | integer!] in globals do [
			repend boot-code either string? args/1 [['change-id/user/group args/1]] [['change-id/user args/1]]
		]
		group: [string! | integer!] in globals do [
			unless empty? boot-code [change boot-code [change-id/user]]
			insert boot-code reduce ['change-gid args/1]
		]
	]
]