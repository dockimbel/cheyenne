REBOL [
	Title: "Mod CORS"
	Purpose: "CORS support for Cheyenne"
	File: %mod-cors.r
	Author: "Nenad Rakocevic"
	Date: 01/08/2013
	Note: "Work sponsored by Alan MacLeod"
]

install-HTTPd-extension [
	name: 'mod-cors
	
	order: [
		method-support	first
		access-check	first
	]
	
	rules: make block! 2
	
	match-host?: func [host origin /local spec][
		origin: any [
			find/match origin "http://" 				;-- skip the http prefix
			origin
		]
		all [
			spec: select rules host
			any [
				spec/1 = '*
				spec: select spec origin
			]
			spec
		]
	]
	
	on-reload: does [
		clear rules
	]
	
	method-support: func [req][	
		if find req/in/headers 'Origin [return true]	;-- passthru for HTTP methods
		none
	]
	
	access-check: func [req /local url spec ri ro list req-method headers][
		ri: req/in/headers
		if all [
			url: select ri 'Origin 
			spec: match-host? req/vhost url 
		][
			ro: req/out/headers
			h-store ro 'Access-Control-Allow-Origin url

			either req/in/method = 'OPTIONS	[			;-- preflight request

				if req-method: select ri 'Access-Control-Request-Method [
					list: any [
						select spec 'methods
						[GET HEAD POST PUT DELETE]		;-- default allowed method if no restriction
					]
					buf: make string! 10
					foreach method list [
						insert tail buf form method
						insert tail buf ", "
					]
					clear back back tail buf
					h-store ro 'Access-Control-Allow-Methods buf
				]
				if headers: select ri 'Access-Control-Request-Headers [
					h-store ro 'Access-Control-Allow-Headers headers
				]
				req/out/code: 200
				req/out/content: "Preflight request accepted"	;-- avoids "no content" catching
				return true
			][											;-- simple request
				if find spec 'cookies [
					h-store ro 'Access-Control-Allow-Credentials "true"
				]
				if list: select spec 'headers [
					foreach h list [
						h-store ro 'Access-Control-Expose-Headers form h
					]
				]
				return false
			]
		]
		none
	]
	
	words: [
		allow-cors: [block!] 'from ['* | string! | word!] in main do [
			use [rules list][
				rules: service/mod-list/mod-cors/rules
				unless list: select rules vhost [
					repend rules [vhost list: make block! 2]
				]
				either args/2 = '* [
					insert list reduce ['* args/1]
				][
					repend list [form args/2 args/1]
				]
			]
		]
	]
]