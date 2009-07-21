REBOL []

do-cache uniserve-path/libs/decode-cgi.r

install-HTTPd-extension [
	name: 'mod-embed
	
	;-- Take precedence over any other module
	order: [
		method-support	first
		url-translate 	first
		url-to-filename first
		parsed-headers	first
		filter-input	first
		access-check	first
		filter-output	first
		reform-headers	first
		logging			first
		clean-up		first
	]	
	
	;-- Disable all other phases
	method-support:
	url-translate:
	url-to-filename:
	parsed-headers:
	filter-input:
	filter-output:
	reform-headers:
	logging:
	clean-up: func [req][true]
	
	site: params: none
	
	set 'publish-site func [spec [block!]][
		site: context spec
	]	
	
	access-check: func [req /local node name target result][
		params: decode-params req
		if in site 'on-request [
			if site/on-request req params service [return true]
		]
		node: site
		parse next req/in/path [
			any [copy name to "/" skip (
				name: to word! name
				unless in node :name [break]
				node: node/:name
			)]
		]
		target: any [
			all [
				req/in/target
				not empty? req/in/target
				attempt [target: to word! req/in/target]
				function? get in node :target
				in node :target
			]
			'default
		]
		
		if error? result: try [node/:target req params service][
			result: mold disarm result
		]
		req/out/content: form any [result ""]
		if in site 'on-response [site/on-response req params service]
		true
	]
		
	words: []
	
; === Helper functions ===
	
	;-- quick implementation of multipart decoding :
	;	- doesn't support multipart/mixed encoding yet
	;	- doesn't parse all optional headers

	decode-multipart: func [data /local bound list name filename value pos][
		parse/all data/in/headers/Content-type [
			thru "boundary=" opt dquote copy bound [to dquote | to end]
		]
		unless bound [return ""]	 ;-- add proper error handler
		insert bound "--"	
		list: make block! 2
		parse/all data/in/content [
			some [
				bound nl some [
					thru {name="} copy name to dquote skip
					[#";" thru {="} copy filename to dquote | none]
					thru crlfx2 copy value to bound (
						clear back back tail value ; -- delete ending crlf (watch out for cr or lf only!!)
						insert tail list name
						either filename [						
							insert/only tail list reduce [filename value]
						][
							insert tail list value
						]
						filename: none
					) | "--"
				]
			]
		]		
		list
	]

	decode-params: func [req /local list][
		list: any [
			switch req/in/method [
				GET	[
					all [				
						req/in/arg
						clear find/last req/in/arg #"#"
					]
					req/in/arg
				]
				POST [
					either all [
						type: select req/in/headers 'Content-type
						find/part type "multipart/form-data" 19
					][
						decode-multipart req/in/content
					][
						req/in/content
					]
				]
			]
			""
		]		
		if any-string? list [list: decode-cgi list] ; TBD: optimize decode-cgi		
		while [not tail? list][
			poke list 1 to word! first list 
			list: skip list 2
		]
		head list
	]
]