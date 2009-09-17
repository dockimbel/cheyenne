REBOL [
	Title: "Email sending library"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Version: 1.0.0
]

email: context [
	charset-str: none
	root: join what-dir %outgoing/
	random/seed now/time/precise

	system/standard/email: make system/standard/email [
		Content-Transfer-Encoding: "8bit"
		X-Rebol: none
		attach: charset: report: none
	]
	nue: second get in net-utils 'export	;-- patch net-utils/export
	nue/16/5/5/5: 'crlf

	bab: second :build-attach-body			;-- patch build-attach-body
	bab/8/6/7: 'crlf
	s: none
	parse bab rule: [some [[set s string! (replace/all s "^/" crlf)] | into rule | skip]]
	ctype: bab/13/4/2	

	not-ascii7: charset [#"^(00)" - #"^(1F)" #"^(80)" - #"^(ff)"]
	not-ascii7-strict: union not-ascii7 charset " "

	encode-word: func [s [string!]][		;-- RFC 2047 encoding
		if not find s not-ascii7 [return s]
		s: convert s [not-ascii7-strict][
			either value/1 = #" " [#"_"][
				as-string back insert skip to-hex to integer! value/1 6 #"="
			]
		]
		insert s reduce ["=?" charset-str "?Q?"]
		append s "?="
	]

	encode-contacts: func [list header /local out][
		out: make string! 20
		if all [2 = length? header string? header/1][header: reduce [header]]
		foreach eml header [
			either block? eml [
				append out reduce [encode-word eml/1 " <" eml/2 ">, "]
				eml: eml/2
			][
				append out eml
				append out ", "
			]
			append list eml
		]
		head clear back back tail out
	]

	blockify: func [value][any [all [not block? value reduce [value]] value]]

	add-header: func [msg [string!]][head insert msg debase/base to-hex length? msg 16]

	make-filename: has [name][
		name: make file! 8
		until [
			clear name
			loop 8 [append name #"`" + random 26]
			not exists? root/:name
		]
		name
	]

	set 'send-email func [h [block!] msg [string!] /local bound name from t-list id report v][
		if not exists? root [make-dir root]
		h: make system/standard/email h

		charset-str: any [h/charset "ISO-8859-1"]
		h/charset: none

		if string? h/from [h/from: to-email h/from]
		if string? h/to   [h/to:   to-email h/to]
		
		foreach name [from to subject][
			if any [none? h/:name empty? h/:name][
				make error! join "Incomplete email specification, lacks : " mold name
			]
		]
		t-list: make block! length? h/to
		h/to: encode-contacts t-list blockify h/to
		if h/cc  [h/cc: encode-contacts t-list blockify h/cc]
		if h/bcc [
			foreach eml blockify h/bcc [append t-list either block? eml [eml/2][eml/1]]
			h/bcc: none
		]
		h/from: encode-contacts from: copy [] blockify h/from

		h/subject: encode-word h/subject
		if none? h/date [h/date: to-idate now]
		
		if h/report [
			report: h/report
			forall report [if set-word? report/1 [report/1: to word! report/1]]
			report: head report
			if block? v: report/from [v/1: encode-word v/1]
			if v: report/subject [v: encode-word v]
			if word? v: report/body [report/body: get v]
			h/report: none
		]

		msg: copy msg
		replace/all msg "^/" crlf

		either h/attach [
			bound: rejoin ["--__REBOL--CHEYENNE--RSP--" checksum form now/precise "__"]
			h/MIME-Version: "1.0"
			h/Content-Type: join "multipart/mixed; boundary=" [{"} skip bound 2 {"}]
			append clear ctype rejoin [
				{^M^/Content-Type: text/plain; charset="} charset-str {"^M^/}
				{Content-Transfer-Encoding: 8bit^M^/}
			]
			h/Content-Transfer-Encoding: none
			msg: build-attach-body msg blockify h/attach bound
			insert msg crlf
			h/attach: none
		][
			h/Content-Type: rejoin [ {text/plain; charset="} charset-str {"}]
		]

		msg: head insert tail h: net-utils/export h msg
		replace/all msg "^/." "^/.."
		name: make-filename			
		write/binary root/:name msg

		id: checksum append h random 999999
		msg: mold/all reduce [from/1 t-list name id report]
		write/direct/no-wait/binary tcp://127.0.0.1:9803 add-header msg
		id
	]

	set 'email-info? func [id [integer!] /local p res][
		 attempt [
			p: open/direct tcp://127.0.0.1:9803
			insert p add-header join "I" id
			res: load copy p
			close p
			res
		]	
	]
]

protect [send-email email-info?]