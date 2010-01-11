REBOL []

install-HTTPd-extension [
	name: 'mod-upload
	verbose: 0
		
	order: [
		url-translate		first
		upload-file			first
	]
	
	uploads: make block! 100			;-- [id [integer!] req [object!] timestamp [date!]...]
	token: none							;-- declared as global to optimize runtime speed
	digit: charset "0123465789"
	
	store: func [token req /local n][
		n: now
		remove-each [id req ts] uploads [ts + 00:01 < n]	;-- GC tokens older than 1 minute
		repend uploads [token req n]
	]
			
	make-upload-id: has [id][
		until [not find uploads id: random 999999999]
		id
	]

	url-translate: func [req /local ro ctx current total][
		if parse req/in/url [
			"/upload/" ["status/" copy token 1 9 digit | "get-id" (token: 'new)]
		][
			req/cfg: []
			ro: req/out
			ro/code: 200
			ro/mime: 'application/json
			
			either token = 'new [
				ro/content: form make-upload-id 
			][
				either ctx: select uploads to integer! token [
					either ctx/tmp [
						current: ctx/tmp/expected - ctx/tmp/remains
						total:   ctx/tmp/expected
					][
						current: length? any [ctx/in/content ""]					
						total:   any [attempt [to integer! ctx/in/headers/Content-Length] 0]
					]
					ro/content: rejoin [
						#"[" 
						to integer! current / total * 100 #","
						current #","
						total
						#"]"
					]
					h-store ro/headers 'Cache-Control "no-cache, no-store, max-age=0, must-revalidate"
					h-store ro/headers 'Pragma "no-cache"
					h-store ro/headers 'Expires "-1"
				][
					ro/code: 404
					ro/content: reform ["Error:" token "is not a valid upload token!"]
					ro/mime: 'text/plain
				]
			]
			true
		]
		none
	]
	
	upload-file: func [req][
		if parse req/in/url [thru "token=" copy token [1 9 digit] to end][
			store load token req
			true
		]
		none
	]
	
	words: []
]
