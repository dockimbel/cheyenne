REBOL []

install-HTTPd-extension [
	name: 'mod-alias
	
	order: [
		url-to-filename	first
	]
	
	redirects: make hash! 32
	aliases: make hash! 32
	
	url-to-filename: func [req /local list pattern action url][
		; --- Test matching virtual host		
		if list: select redirects req/vhost [
			; -- Test matching patterns on request path	
			url: join req/in/path req/in/target			
			foreach [pattern action] list [		
				if find/any/match url pattern [			
					req/out/code: second action
					if slash = last url: first action [
						insert tail url: copy url join req/in/target any [req/in/arg ""]
					]				
					h-store req/out/headers 'Location url
					return true
				]
			]
		]
		if list: select aliases req/vhost [
			foreach [pattern action] list [
				if find/any/match req/in/url pattern [
					req/in/file: rejoin [req/cfg/root-dir slash action]  ;-- make a smart rejoin!!!
					req/in/script-name: copy pattern
					req/handler: select service/handlers to word! as-string suffix? action					
					return false			;-- let mod-static finish the work
				]
			]
		]
		false
	]
	
	words: [
		alias: [string!] [file!] in main do [
			use [list pos][
				list: service/mod-list/mod-alias/aliases
				unless pos: select list vhost [
					repend list [vhost pos: copy []]
				]
				repend pos [args/1 args/2]
			]
		]
		redirect: [integer!] [string!] [string!] in main do [	
			use [list pos][
				list: service/mod-list/mod-alias/redirects
				unless pos: select list vhost [
					repend list [vhost pos: copy []]
				]
				repend pos [args/2 reduce [args/3 args/1]]
			]
		]
	]
]