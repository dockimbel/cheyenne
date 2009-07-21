REBOL []

install-HTTPd-extension [
	name: 'mod-ssi
	
	order: [
		set-mime-type	normal
		access-check	normal
		make-response	normal
		logging			last
	]
	
	cache: context [
		list: make block! 20
		max-size: 2000 * 1024
		size: 0
		
		words: []
		
		error: ["<html><h2>Error in SSI : " msg "</h2>"]
		
		s-mark: {<!--#include }
		e-mark: {" -->}
		out: start: txt: inc: msg: none
		
		rules: [
			(out: make block! 10)
			any [
				start: copy txt to s-mark (if txt [insert tail out txt])
				s-mark
				copy type to #"=" (inc: reduce [type])
				2 skip 		; ="
				copy value to e-mark (
					insert/only tail out reduce [to-word trim type value]
				)
				e-mark
			]
			copy txt to end (if txt [insert tail out txt])
		]
		
		merge: func [pos /local out path item file ctx s e][
			out: any [
				all [not pos/3 clear pos/3]
				make string! 64 * 1024
			]
			poke pos 3 out
			root: first split-path first pos		
			foreach item pick pos 4 [			
				either block? item [					
					do select [
						virtual [
							either exists? file: join root second item [
								insert tail out read/binary file
							][
								msg: rejoin [file " not found"]
								return rejoin error
							]
							;ctx: service/process-sub-request second item
							;if s: ctx/out/content [
							;	parse/all s [
							;		[to "<body" | to "<html" opt [to "<body"]]
							;		thru ">" s:
							;		[to "</body" | to "</html"] e:
							;	]
							;	either e [
							;		insert/part tail out s e
							;	][
							;		insert tail out s
							;	]
							;]
						]
						file [						
							either exists? file: join root second item [
								insert tail out read/binary file
							][
								msg: rejoin [file " not found"]
								return rejoin error
							]
						]
						set []
						echo []
					]  first item
				][
					insert tail out item
				]
			]
			out
		]
		
		process: func [req /local file pos][
			file: req/in/file			
			if any [
				not pos: find list file
				req/file-info/date > pick pos 2
			][
				parse/all read/binary file rules
				either pos [		
					poke pos 2 now		; -- update
					poke pos 4 out
				][
					pos: tail list		; -- add
					repend list [file now none out]
				]
			]			
			merge pos
		]
	]
	
	declined?: func [req]['SSI <> select service/handlers req/in/ext]
	
	set-mime-type: func [req][
		if declined? req [return none]
		req/out/mime: 'text/html
		true
	]
	
	access-check: func [req /local info mdate][
		; --- This phase is redefined to avoid Last-Modified header generation		
		if declined? req [return none]
		; --- Test if the file can be read		
		unless req/file-info: info? req/in/file [
			req/out/code: 400
		]
		true
	]
	
	make-response: func [req][
		if declined? req [return none]			
		req/out/code: 200
		req/out/content: cache/process req
		true
	]
	
	logging: func [req][
		none
	]
	
]