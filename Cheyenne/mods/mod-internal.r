REBOL []

install-HTTPd-extension [
	name: 'mod-internal
	
	order: [
		url-to-filename first
		logging			first
	]	
	
	allowed: [127.0.0.1]
	
	internal-conf: [
		root-dir %internal
		default %index.rsp
		webapp [
			virtual-root "/admin"
			root-dir %www/admin/
			auth "/admin/login.rsp"
			debug
		]
	]
	
	clean: func [str /local s e][
		parse/all str [
			any [
				s: [".." | #"%" | #"\" | slash | "@"] e: (remove/part s e) | skip
			]
		]
		str
	]
	
	url-to-filename: func [req][
		either all [
			req/in/target
			req/in/path = "/"
			#"@" = pick req/in/target 1
			find allowed service/client/remote-ip
		][
			clean req/in/target
			req/cfg: internal-conf
			unless find req/in/target #"." [
				req/in/target: join req/in/target ".rsp"
				req/handler: select service/handlers req/in/ext: '.rsp
			]			
			false
		][none]
	]
			
	logging: func [req][
		either find req/in/url #"@" [true][none]
	]
		
	words: [
		admin-ip: [tuple! | block!] in globals do [allowed: to-block first args]
	]
]