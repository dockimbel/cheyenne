REBOL [
	file: %mezz.r
	author: "Maxim Olivier-Adlhoch"
	date: 2010-07-08
	version: 0.5.1
	title: "core functions, parse rules & data used throughout cheyenne test-suite"
	
	license-type: 'MIT
	license:      {Copyright © 2010 Maxim Olivier-Adlhoch.

		Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
		and associated documentation files (the "Software"), to deal in the Software without restriction, 
		including without limitation the rights to use, copy, modify, merge, publish, distribute, 
		sublicense, and/or sell copies of the Software, and to permit persons to whom the Software 
		is furnished to do so, subject to the following conditions:
		
		The above copyright notice and this permission notice shall be included in all copies or 
		substantial portions of the Software.}
		
	disclaimer: {THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
		INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
		PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
		FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
		ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
		THE SOFTWARE.}

]



;- WORD BACKUPS
;-    send-mail()
send-mail: :send

;-    at*()
at*: :at

;-    skip*()
skip*: :skip



;-  
;- OBJECTS
;-    !date:
!date: context [
	year:
	month:
	day:
	day-lbl:
	month-lbl:
	hour:
	minute:
	second:
	tz: none	
]







;- PARSE RUlES
;-    -basic character sets
=digit=: charset "0123456789"
=digits=: [some =digit=]
=alpha=: charset [#"a" - #"z" #"A" - #"Z"]
=alphanumeric=: union =digit= =alpha=
=white-space=: charset " ^-"
=white-spaces=: [some =white-space=]
=.=: charset "."

;-    -URL character sets
; as per RFC 1738
unsafe-url-char: complement charset [#"a" - #"z" #"A" - #"Z" "0123456789" "$-_.+!*'()," ]  ;charset [#"^(00)" - #"^(1F)" #"^(7F)" #"^(80)" - #"^(FF)" "{}|\^^~[]`<>#^""]
reserved-url-char: charset [";" "/" "?" ":" "@" "=" "&"]
encode-url-char: exclude unsafe-url-char reserved-url-char


;-    -http based rules <RFC 2068 >
=SP=: charset " "
=SPs=: [some =SP=]
=CTL=: charset [#"^(0)" - #"^(1F)" #"^(7F)"]
=CHAR=: charset [#"^(0)" - #"^(7F)"]
=LOALPHA=: charset [#"a" - #"z"]
=HIALPHA=: charset [#"A" - #"Z"]
=TEXT=: complement =CTL=
=CR=: charset [#"^M"]
=LF=: charset [#"^/"]
=CRLF=: [=CR= =LF=]
=STATUS-TEXT=: exclude =TEXT= charset [ #"^M" #"^/" ]
=tspecials=: charset [
	#"("  #")" #"<" #">" #"@"
	#"," #";" #":" #"\" #"^""
	#"/" #"[" #"]" #"?" #"="
	#"{" #"}" #" " #"^-"
]
=token=: exclude exclude =CHAR= =CTL= =tspecials=
=header-content=: complement charset [ #"^M" #"^/" ]


;-    -http dates
;
;   Sun, 06 Nov 1994 08:49:37 GMT  ; RFC 822, updated by RFC 1123
;   Sunday, 06-Nov-94 08:49:37 GMT ; RFC 850, obsoleted by RFC 1036
;   Sun Nov  6 08:49:37 1994       ; ANSI C's asctime() format (note no timezone!)
;
; here is the grammar as stated in the RFC
;
;       HTTP-date    = rfc1123-date | rfc850-date | asctime-date
;       rfc1123-date = wkday "," SP date1 SP time SP "GMT"
;       rfc850-date  = weekday "," SP date2 SP time SP "GMT"
;       asctime-date = wkday SP date3 SP time SP 4DIGIT
;       date1        = 2DIGIT SP month SP 4DIGIT
;                      ; day month year (e.g., 02 Jun 1982)
;       date2        = 2DIGIT "-" month "-" 2DIGIT
;                      ; day-month-year (e.g., 02-Jun-82)
;       date3        = month SP ( 2DIGIT | ( SP 1DIGIT ))
;                      ; month day (e.g., Jun  2)
;       time         = 2DIGIT ":" 2DIGIT ":" 2DIGIT
;                      ; 00:00:00 - 23:59:59
;       wkday        = "Mon" | "Tue" | "Wed"
;                    | "Thu" | "Fri" | "Sat" | "Sun"
;       weekday      = "Monday" | "Tuesday" | "Wednesday"
;                    | "Thursday" | "Friday" | "Saturday" | "Sunday"
;       month        = "Jan" | "Feb" | "Mar" | "Apr"
;                    | "May" | "Jun" | "Jul" | "Aug"
;                    | "Sep" | "Oct" | "Nov" | "Dec"

;------
; these variables are used by the date rules below.
;------
date-parse-storage: dps: make !date [] 
val: none

=wkday=:      [ "Mon" | "Tue" | "Wed" | "Thu" | "Fri" | "Sat" | "Sun"]
wkdays: [ "Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun"]

=weekday=:    [ "Monday" | "Tuesday" | "Wednesday" | "Thursday" | "Friday" | "Saturday" | "Sunday" ]
weekdays:  [ "Monday"  "Tuesday"  "Wednesday"  "Thursday"  "Friday"  "Saturday"  "Sunday" ]

=month=:      [ "Jan" | "Feb" | "Mar" | "Apr" | "May" | "Jun" | "Jul" | "Aug" | "Sep" | "Oct" | "Nov" | "Dec" ]
months:      [ "Jan"  "Feb"  "Mar"  "Apr"  "May"  "Jun"  "Jul"  "Aug"  "Sep"  "Oct"  "Nov"  "Dec" ]

 ; day month year (e.g., 02 Jun 1982)
=date1=: [ 
	copy val 2 =DIGIT= (dps/day: to-integer val) =SP= 
	copy val   =month= (dps/month: index? find months val) =SP= 
	copy val 4 =DIGIT= (dps/year: to-integer val)
]

; day-month-year (e.g., 02-Jun-82)       
=date2=: [ 
	copy val 2 =DIGIT= "-" (dps/day: to-integer val)
	copy val   =month= "-" (dps/month: index? find months val)
	copy val 2 =DIGIT=  (dps/year: 2000 + to-integer val   if (dps/year - now/year) >= 50 [dps/year: dps/year - 100][])
]

; month day (e.g., Jun  2)
=date3=: [ 
	copy val =month= =SP= (dps/month: index? find =month= val)
	 [ copy val 2 =DIGIT= | [ =SP= copy val =DIGIT= ]] (dps/day: to-integer val)
] 
; 00:00:00 - 23:59:59
=time=: [ 
	copy val 2 =DIGIT= ":" (dps/hour:   to-integer val)
	copy val 2 =DIGIT= ":" (dps/minute: to-integer val)
	copy val 2 =DIGIT=     (dps/second: to-integer val)
]       
rfc1123-date: [ =wkday= "," =SP= =date1= =SP= =time= =SP= "GMT" (dps/tz: "GMT") ]
rfc850-date:  [ =weekday= "," =SP= =date2= =SP= =time= =SP= "GMT" (dps/tz: "GMT")]
asctime-date: [ =wkday= =SP= =date3= =SP= =time= =SP= copy val 4 =DIGIT= (dps/year: to-integer val) (print "asctime-date") ]

; note that dates have to be parsed CASE SENSITIVE.
HTTP-date: [rfc1123-date | rfc850-date | asctime-date]



;-  
;- SERIES FUNCTIONS 

;--------------------
;-    merge()
;--------------------
merge: func [
	container "series to insert into" [series!]
	data "data to insert within, single value or series, a single value will be repeated as needed to reach end of container."
	/zero "zero-based indexing, /at 1 will in fact "
	/skip step [integer!] "skip container records when merging" 
	/every n [integer!]   "view the data as fixed-sized records, first being always inserted. (ex: 2= 1 3 5 7)"
	/amount a [integer!]  "insert this many elements from data at a time, if every is specified, this amount cannot be larger than it."
	/at ata [integer! none!] "skip records in record before merge, none=1. note /zero is basis, if used (will insert before first record)"
	/only "treat series data as single values (repeating the series in container till the end).  Note that data is not copied."
	/local repeat
][
	; usefull copy to end use of merge
	if any [
		not series? data
		only
	][data: head insert tail copy [] data repeat: true]
	
	either skip [step: step + 1][step: 1]
	unless every [n: 1]
	unless amount [a: 1]
	unless zero [container: at* container (step + 1)]
	if at [
		if none? ata [ata: 1]
		container: skip* container (ata * step)
	]
	
	; change amount functionality based on if every is specified.
	if every [
		either n >= a [n: n - a + 1][to-error "merge: amount cannot be larger than every"]
	]
	
	until [
		loop a [unless tail? data [
				container: insert/only container first data
				unless repeat [
					data: at* data 2 ; skip to next item in data
				]
		]]
		
		;stop merging past container
		if tail? container [
			data: tail data
		]

		container: at* container step + 1
		unless repeat [
			data: at* data n
		]

		any [ tail? data ]
	]
	first reduce [head container container: none data: none]
]



;- NETWORK FUNCTIONS



;-----------------
;-    parse-http-date()
;
; breaks up the http date into its constituents.
;
; the RFC states that dates ARE case-sensitive (sect. 3.3.1)
;


;-----------------
parse-http-date: func [
	data "if input is not a string, it always returns none."
	/local date
][
	vin [{parse-http-date()}]
	either string? data [
		if parse/case/all data HTTP-date [
			; copy the date into a unique instance
			date: make date-parse-storage []
		]
	][
		date: none
	]
	vout
	
	date
]



URL-Parser: make object! [
	scheme: none
	user: none
	pass: none
	host: none
	port-id: none
	path: none
	target: none
	tag: none
	p2: none
	vars: [user pass host port-id path target]
	digit: make bitset! #{000000000000FF03000000000000000000000000000000000000000000000000}
	alpha-num: make bitset! #{000000000000FF03FEFFFF07FEFFFF0700000000000000000000000000000000}
	scheme-char: make bitset! #{000000000068FF03FEFFFF07FEFFFF0700000000000000000000000000000000}
	path-char: make bitset! #{00000000F57FFFAFFFFFFFAFFEFFFF5700000000000000000000000000000000}
	user-char: make bitset! #{00000000F87CFF2BFEFFFF87FEFFFF1700000000000000000000000000000000}
	pass-char: make bitset! #{FFF9FFFFFEFFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
	url-rules: [scheme-part user-part host-part path-part file-part tag-part]
	scheme-part: [copy scheme some scheme-char #":" ["//" | none]]
	user-part: [copy user uchars [#":" pass-part | none] #"@" | none (user: pass: none)]
	pass-part: [copy pass to #"@" [skip copy p2 to "@" (append append pass "@" p2) | none]]
	host-part: [copy host uchars [#":" copy port-id digits | none]]
	path-part: [copy path [slash  path-node] | none]
	path-node: [pchars slash path-node | none]
	file-part: [copy target pchars | none]
	tag-part: [#"#" copy tag pchars | none]
	uchars: [some user-char | none]
	pchars: [some path-char | none]
	digits: [1 5 digit]
	parse-url: func [
		{Return url dataset or cause an error if not a valid URL}
		url
		/within port [object! port!]
		/ignore-scheme "Don't set port scheme"
		/no-error "Do not throw an error, return NONE instead."
	][
		set vars none
		ctx: any [
			port context [
				user: pass: host: port-id: path: target: scheme: none
			]
		]
		either parse/all url url-rules [
			vprobe reduce ["URL Parse:" reduce vars]
			if user [ctx/user: user]
			if pass [ctx/pass: pass]
			if host [ctx/host: host]
			if port-id [ctx/port-id: to-integer port-id]
			if path [ctx/path: path]
			if target [ctx/target: target]
			if all [not ignore-scheme scheme] [ctx/scheme: to-word scheme]
			ctx
		] [either no-error [vprint "Error parsing url"][to-error join "URL parsing error:" url]]
	]
]

;-----------------
;-    split-url()
;
; given a url, returns an object with all url items split into
; different attributes.
;
; url parser object is taken fron net-utils and refurbished.
;-----------------
split-url: func [
	url [url!]
	/local result
][
	vin [{parse-url()}]
	result: url-parser/parse-url url
	if none? result/path [
		result/path: copy "/"
	]
	vout
	
	first reduce [result result: none]
]



;-----------------
;-    url-encode()
; as per RFC 1738 http://www.ietf.org/rfc/rfc1738.txt
;-----------------
url-encode: func [
	str [string! binary!]
	;/all "encode even url characters"
][
	vin [{url-encode()}]
	parse/all str [
		any [
			here: encode-url-char (change/part here rejoin ["%" enbase/base to-string first here 16] 1 here: next next here) :here
			| skip
		]
	]
	
	vout
	str
]





;-----------------
;-    resolve()
;-----------------
resolve: func [
	"Copy context by setting values in the target from those in the source."
	[catch]
	target [object! port!]
	source [object! port!]
	/only from [block! integer!] "Only specific words (exports) or new words in target (index to tail)"
	/all "Set all words, even those in the target that already have a value"
][
	either only [
		from: either integer? from [
			; Only set words in the target positioned at the number from or later
			unless positive? from [throw-error 'script 'out-of-range from]
			intersect words-of source at words-of target from
		] [
			; Only set the words in the target that are also in the from block
			intersect words-of source intersect words-of target from
		]
		foreach word from pick [
			[unless value? in target word [error? set/any in target word get/any word]]
			[error? set/any in target word get/any word]
		] not all ; See below for what this means
	] [
		either all [ ; Override all target words even if they have values
			error? set/any bind words-of source target get/any source
		] [ ; Only set target words if they aren't yet set
			foreach word intersect words-of source words-of target [
				unless value? in target word [error? set/any in target word get/any word]
			]
		]
	]
	also target set [source target from] none
]


;;-----------------
;; -    words-of()
;;-----------------
;words-of: func [
;	ctx [object!]
;][
;	next first ctx
;]
;
;
;;-----------------
;; -    values-of()
;;-----------------
;values-of: func [
;	ctx [object!]
;][
;	next second ctx
;]



