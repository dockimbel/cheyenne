REBOL []

install-HTTPd-extension [
	name: 'mod-userdir
	
	order: none
	lf: #"^/"
	col: #":"
	
	boot-code: []
	
	on-started: does [do boot-code]
	on-reload:  does [clear boot-code]
	
	get-ugid: func [name [string!] /local file uid gid][
		if none? attempt [file: read %/etc/passwd][
			log/error "accessing /etc/passwd failed"
			return none
		]
		unless parse/all file [
			thru name 2 [thru col]
			copy uid to col skip
			copy gid to col
			to end
		][
			log/error "reading /etc/passwd failed"
			return none
		]
		reduce [to-integer uid to-integer gid]
	]
	
	change-id: func [id [word! integer!] /user /group][
		if word? id [
			if none? id: get-ugid mold id [return none]
			id: pick id to-logic user
		]
		either user [
			;logger/file.log: join logger/file ["-" id %.log]
			setuid id
		][setgid id]
	]
	
	words: [
		user: [word! | integer!] in globals do [
			repend boot-code ['change-id/user to-lit-word args/1]
		]
		group: [word! | integer!] in globals do [
			repend boot-code ['change-id/group to-lit-word args/1]
		]
	]
]