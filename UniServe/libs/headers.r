REBOL [
	Title: "HTTP Headers lib"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Version: 1.0.0
	Comment: {
		A header block is a simple structure fo storing HTTP header name/value pairs.
		Each name is unique in the structure. Values can be : none!, a string!
		or a block of string!.
		
		structure: [
			name1 	"value1" | ["value1" "value2" ...] | none
			name2	...
		]
	}
]

h-store: func [
	"Store a header name/value pair in a header block"
	headers	[block!]		"Header block"
	name [word! string!]	"Header Name"
	value [string! none!]	"Value to store"
	/locals pos
][
	either pos: find headers name [
		either block? pos/2 [
			insert tail pos/2 value
		][
			poke pos 2 any [
				all [
					find [Set-Cookie Set-Cookie2] name
					pos/2
					reduce [pos/2 value]
				] value
			]
		]
	][
		insert tail headers name
		insert tail headers value
	]
]

foreach-nv-pair: func [
	{Iterates through a block header and evaluates the body block
	for each name/value pair found. None! values will be skipped
	'Name and 'Value words are exposed in the body block}
	headers [block!]	"Header block"
	body [block!]		"Body to evaluate for each pair"
][
	foreach [name value] headers [
		bind body 'name
		either block? value [
			foreach val value [value: val do body]
		][
			do body
		]
	]
]	

form-header: func [
	"Build a string with all the name/value pairs in a header block"
	headers	[block!]	"Header block"
	/local out
][
	out: make string! 512
	foreach-nv-pair headers [
		if value [insert tail out reduce [name ": " value crlf]]
	]
	insert tail out crlf
	copy out		;-- TBD: investiguate on this 'copy
]