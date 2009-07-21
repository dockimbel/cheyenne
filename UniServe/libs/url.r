REBOL []

context [
	digit: charset "0123456789"
	alpha: charset [#"a" - #"z" #"A" - #"Z" "-_%"]
	alphanum: union alpha digit
	host-char: complement charset "@:/"
	v1: v2: v3: v4: v5: v6: v7: none
	
	obj: context [
		scheme: user: pass: host: port-id: path: target: none
	]

	set 'parse-url func [url [string! url!]][
		v1: v2: v3: v4: v5: v6: v7: none
		parse/all url [
			copy v1 to "://" 3 skip (v1: to word! v1) [
				copy v2 any host-char [
					#":" copy v3 any host-char 
					| (v3: none) none
				] #"@"
				| (v2: v3: none) none
			]
			copy v4 any host-char [
				#":" copy v5 1 5 digit (v5: to integer! v5)
				| (v5: none) none
			][
				end 
				| [
					[
						copy v6 [slash any [some alphanum slash]]
						| none				
					]
					[copy v7 to end]
				]
			]
		]	
		obj/scheme: v1
		obj/user: v2
		obj/pass: v3
		obj/host: v4
		obj/port-id: v5
		obj/path: v6
		obj/target: v7
		obj
	]
]
