REBOL [
	Title: "Email sending library"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Version: 1.1.0
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
	
	export: func [obj [object!] /local out][
		out: make string! 512
		foreach [n v] third obj [if v [repend out [n ": " v crlf]]]
		out
	]
	
	make-mime-header: func [file][
		export context [
			Content-Type: join {application/octet-stream; name="} [file {"}]
			Content-Transfer-Encoding: "base64"
			Content-Disposition: join {attachment; filename="} [file {"^M^/}]
		]
	]
	
	break-lines: func [msg data /local num][
		num: 72
		while [not tail? data] [
			insert/part tail msg data num
			insert tail msg crlf
			data: skip data num
		]
		msg
	]
	
	build-attach-body: func [
		body [string!]
		files [block!] {List of files to send [%file1.r [%file2.r "data"]]}
		boundary [string!]
		ctype
		/local file	val
	][
		if not empty? files [
			insert body reduce [boundary ctype]
			append body "^M^/^M^/"
			if not parse files [
				some [
					(file: none)
					[
						set file file! (val: read/binary file)
						| into [
							set file file!
							set val skip ;anything allowed
							to end
						]
					] (
						if file [
							repend body [
								boundary "^M^/"
								make-mime-header any [find/last/tail file #"/" file]
							]
							val: either any-string? val [val] [mold :val]
							break-lines body enbase val
						]
					)
				]
			] [net-error "Cannot parse file list."]
			append body join boundary "--^M^/"
		]
		body
	]

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
			append list any [all [email? eml eml] to email! eml]
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
			foreach eml blockify h/bcc [append t-list to email! either block? eml [eml/2][eml/1]]
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
			h/Content-Transfer-Encoding: none
			msg: build-attach-body msg blockify h/attach bound rejoin [
				{^M^/Content-Type: text/plain; charset="} charset-str {"^M^/}
				{Content-Transfer-Encoding: 8bit^M^/^M^/}
			]
			insert msg crlf
			h/attach: none
		][
			h/Content-Type: rejoin [ {text/plain; charset="} charset-str {"}]
		]

		h: export h
		msg: append append h crlf msg
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