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
			
	make-upload-id: has [id][
		until [not find uploads id: random 999999999]
		id
	]

	url-translate: func [req /local ctx current total][
		if parse req/in/url [
			"/upload/" ["status/" copy token 1 9 digit | "get-id" (token: 'new)]
		][
			req/cfg: []
			req/out/code: 200
			req/out/mime: 'application/json
			
			either token = 'new [
				req/out/content: form make-upload-id 
			][
				either ctx: select uploads to integer! token [
					either ctx/tmp [
						current: ctx/tmp/expected - ctx/tmp/remains
						total:   ctx/tmp/expected
					][
						current: length? any [ctx/in/content ""]					
						total:   any [attempt [to integer! ctx/in/headers/Content-Length] 0]
					]
					req/out/content: rejoin [
						#"[" 
						to integer! current / total * 100 #","
						current #","
						total
						#"]"
					]
				][
					req/out/code: 404
					req/out/content: reform ["Error:" token "is not a valid upload token!"]
					req/out/mime: 'text/plain
				]
			]
			true
		]
		none
	]
	
	upload-file: func [req][
		if parse req/in/url [thru "token=" copy token [1 9 digit] to end][
			token: load token
			repend uploads [token req now]
			true
		]
		none
	]
	
	words: []
]
