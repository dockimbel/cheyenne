REBOL []	

comment {
[none
	"com" [
		none
		"test"  [
			cookies | none
			"sub1" [...]
			"sub2" [
				cookies | none
				"sub3" [...]
				...
			]
			...
		]
		...
	]
	...
]

cookies: [
	path1 [name1 [...] name2 [...]]
	path2 [...]
]
	
}

;do-cache uniserve-path/libs/log.r
do-cache uniserve-path/libs/idate.r
	
cookies: make log-class [
	name: 'cookies
	verbose: 2
	
	db: reduce [none]
	v: none

	proto: context [
		name: value: expires: path: domain: secure: max-age: version: 
		comment: sub?: kill-date: none
	]
	
	count: func [s [series!] value /local n][
		n: 0
		parse/all s [any [value (n: n + 1) | skip]]
		n
	]
	
	chars: complement charset ";"
	dquote: #"^""
	
	copy-rule: [#"=" opt dquote copy v some chars opt dquote [#";" | end]]
	
	decode: func [data [string!] /local new][
		new: make proto []		
		parse data [
			copy v to #"=" (new/name: v)
			copy-rule (new/value: v) any [
				"domain" copy-rule (new/domain: v)
				| "path" copy-rule (new/path: v)
				| "expires" copy-rule (new/expires: v)
				| "max-age" copy-rule (new/max-age: v)
				| "version" copy-rule (new/version: v)
				| "comment" copy-rule (new/comment: v)
				| "secure" [to #";" | to end] (new/secure: true)
			]
		]
		new
	]
	
	store: func [
		domain [string!] path [string!] spec [string!]
		/local new name pos base value rem? data m-path
	][
		new: decode spec
	
		;if all [new/domain lesser? length? domain length? new/domain][return false]
		if all [new/path find/any/match new/path join "*" path][path: new/path]
		if all [
			new/domain
			find/any/match new/domain join "*" domain 
			2 <= count new/domain #"."
		][
			if #"." = first domain: new/domain [
				remove domain
				new/sub?: yes
			]
		]
		
		base: db
		domain: head reverse parse domain "."
		remove-each pos domain [empty? pos]
		;if 2 > length? domain [return false]
		
		;-- Find the right place for the cookie, build it if necessary
		while [not tail? domain][
			if not pos: select base first domain [
				append base first domain
				append/only base pos: reduce [none]
			]
			base: next pos
			domain: next domain
		]
		
		;-- Determine if the cookie has to be removed
		rem?: to logic! either all [
			new/max-age
			value: attempt [to integer! new/max-age] 
			zero? value
		][
			yes
		][
			all [
				value: any [
					all [value now + to time! value]
					all [new/expires to-rebol-date new/expires]
				]
				now > new/kill-date: value + now/zone
			]
		]
		data: first base: head base	
		;-- If to be removed and not found in DB, exit
		if all [rem? none? data][return false]
		;-- Store it or remove it
		either rem? [
			if any [
				none? m-path: select data path
				none? pos: find m-path new/name
			][return false]
			remove/part pos 2
		][
			if none? data [change/only base data: make block! 1]
			if none? m-path: select data path [
				insert tail data path
				insert/only tail data m-path: make block! 1
			]
			either pos: find m-path new/name [
				change next pos new
			][
				insert tail m-path new/name
				insert tail m-path new
			]			
		]
		new
	]

	destroy: func [][

	]

	build: func [domain [string!] path [string!] /local base data][
		out: make string! 16
		base: db
		domain: head reverse parse domain "."
		remove-each pos domain [empty? pos]
		while [not tail? domain][
			if not pos: select base first domain [return none]
			base: next pos
			domain: next domain
		]	
		if not pos: select first base: head base path [return none]
		foreach [name obj] pos [
			insert tail out name
			insert tail out #"="
			insert tail out obj/value
			insert tail out "; "
		]
		clear back back tail out
		out
	]

	show: has [rule domain cookies out path list value][			;-- for debugging only
		print "---- Cookie DataBase ----"
		if empty? db [print "empty" exit]
		domain: make block! 1
		cookies: [
			(
				out: copy "+ "
				foreach p domain [repend out [p #"."]]
				remove back tail out
				print out
			)
			some [
				set path string! set list block! (
					print [tab path]
					foreach [name obj] list [
						prin [tab tab name "=" obj/value]
						if obj/expires [
							prin ["; expires=" obj/expires #"(" obj/kill-date #")"]
						]
						if obj/max-age [
							prin ["; max-age=" obj/max-age #"(" obj/kill-date #")"]
						]
						prin newline
					]
				)
			]
		]
		parse db rule: [
			[none! | into cookies]
			any [
				set value string! (insert domain value)
				[into rule (remove domain) | none]
			]
		]
	]
]

{
#test [

]

probe cookies/store ".test.com" "/" "CUSTOMER=WILE_E_COYOTE; path=/; expires=Wednesday, 09-Nov-2006 23:12:40 GMT"
probe cookies/store "test.com" "/" "SHIPPING=FEDEX; path=/foo"
probe cookies/store "test.com" "/" "SID=AZERTYUIOP; path=/foo; max-age=10000"
probe cookies/build "test.com" "/"
probe cookies/build "test.com" "/foo"
probe cookies/store "localhost" "/toto/" "Titi=3"
Set-Cookie: FPB=i3uitkb7r12eh2h1; expires=Thu, 01 Jun 2006 19:00:00 GMT; path=/; domain=www.yahoo.com
cookies/show
;halt

}

