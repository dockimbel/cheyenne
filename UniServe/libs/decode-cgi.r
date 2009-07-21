REBOL [
	Title: "Decode-cgi library"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Version: 1.0.0
	Date: 26/06/2007
]

context [
	chars: complement charset "&="

	set 'decode-cgi func [
		data [any-string!]
		/raw
		/with list
		/local out type! name value s pos
	][
		out: any [list make block! 8]
		type!: any [all [raw word!] set-word!]
		parse/all data [
			any [
				 #"&"
				| copy name some chars opt #"=" opt [copy value some chars] (
					value: any [value ""]
					parse/all value [any [s: #"+" (change s #" ") | skip]]
					value: dehex value
					either pos: find/skip out name: to type! name 2 [
						insert tail any [
							all [block? s: second pos s]
							poke pos 2 reduce [s]
						] value
					][
						insert tail out name
						insert tail out value
					]
					value: none
				)
			]
		]
		out
	]
]
