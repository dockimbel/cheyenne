REBOL []

conf-parser: make log-class [
	name: 'conf-parser
	verbose: 0
	
	location: folder: main-rules: string-rules: file-rules:
	global-rules: symbols: args: value: err: service: module: mode: 
	vhost: scope: none
	
	cfg-file:  %httpd.cfg
	
	sym-proto: [
		'globals	global-rules
		'main		main-rules
		'location	string-rules
		'folder		file-rules
	]
	
	reset: does [
		main-rules:	  make block! 8
		string-rules: make block! 8
		file-rules:   make block! 8
		global-rules: make block! 8
		symbols: reduce sym-proto
		recycle
	]
	
	clean-rules: does [
		foreach rule extract/index sym-proto 2 2 [
			if all [
				not empty? rule: get rule
				'| = last rule
			][
				remove back tail rule
			]
		]
	]
	
	host-rules: [
		scope: 
		any [err: (mode: 'main) main-rules]
		any [
			err: set location string! (mode: 'location) into [any string-rules]
			| set folder file! (mode: 'folder) into [any file-rules]
		]
	]
	
	conf-rule: [
		err: 'globals (mode: 'globals) into [any [err: global-rules]]
  		some [set vhost [word! | tuple! | url! | string!] into host-rules]
	]
	
	read: func [svc /local word rules name list file conf data][
		reset
		service: svc
		foreach [word rules] symbols [
			if all [not empty? rules '| = last rules][
				remove back tail rules
			]
		]	
		file: either slash = first cfg-file [cfg-file][
			cheyenne/data-dir/:cfg-file
		]
		conf: load either exists? file [file][	
			either encap? [
				data: as-string read-cache cfg-file
				write file data
				data
			][
				cfg-file	; -- local debug mode (not used in production)
			]
		]	
		unless all [
			'modules = pick conf 1
			block? pick conf 2
		][
			throw 'invalid-conf-modules
		]
		svc/mod-list: make block! 8	
		foreach name conf/2 [
			name: to-word join "mod-" name
			append svc/mod-list name
			file: join svc/mod-dir [name ".r"]	
			if svc/verbose > 0 [log/info ["Loading extension: " mold :name]]		
			append svc/mod-list do-cache file
		]
		recycle	
		clean-rules	
		unless parse skip conf 2 conf-rule [
			log/error ["error in conf file at:" mold/only copy/part err 5]
			;throw 'invalid-conf-syntax
		]	
		service: none
		conf
	]

	process: func [data [block!]][
		parse data reduce ['any select symbols mode]
	]
	
	add-rules: func [spec /local out word arg scope action][	
		unless parse spec [
			any [
				(out: make block! 16)
				set word set-word! (
					append out to-lit-word word
					append out [(args: make block! 2)]
				) 
				any [
					set arg	block! (
						repend out [
							'set 'value any [
								all [1 = length? arg first arg]
								arg
							]
						]
						append out [(append/only args value)]
					)
					| set arg lit-word! (
						append out to-lit-word arg
					)
				]
				'in set scope skip
				opt ['do set action block! (
					repend out [to-paren bind action 'self]
				)](
					scope: to-block scope
					foreach word scope [
						repend select symbols word [out '|]
					]
				)
			]
		][
			;throw 'invalid-keyword-rule
			print "invalid keyword rule"
		]
	]
]