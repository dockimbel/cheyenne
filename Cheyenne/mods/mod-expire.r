REBOL [
	date: 21-Dec-2008
	version: .03
	author: {Will Arp}
]

; ---
; add 'expires in httpd.cfg/modules
; put something like this in httpd.cfg/globals
; 
; expires [
; 	image/x-icon 604800	;time to cache in seconds
; 	image/gif 604800
; 	image/jpeg 604800
; 
; 	text/html 600
; 	text/css 600
; 	application/x-javascript 600
; ]
; ---


install-HTTPd-extension [
	name: 'mod-expire

	order: [
		reform-headers last
		;change to first if you want expires applied to rsp,
		;then you will have to explicitly negate caching in
		;your script if needed, as mod-action will set no
		;caching by default.
	]

	expires: none
	
	reform-headers: func [req /local time seconds roh][
		all [
			expires
			roh: req/out/headers
			not find roh 'Expires
			seconds: select/only expires req/out/mime
			time: now
			h-store req/out/headers 'Expires to-GMT-idate/UTC (time + to time! seconds)
			;http://blog.pluron.com/2008/07/why-you-should.html
			h-store req/out/headers 'Cache-Control rejoin ["public, max-age=" seconds]
			not find roh 'Last-Modified
			h-store req/out/headers 'Last-Modified to-GMT-idate/UTC time
		]
		false
	]

	words: [
		expires: [block!] in [globals] do [
			expires: to hash! args/1
		]
	]
]












