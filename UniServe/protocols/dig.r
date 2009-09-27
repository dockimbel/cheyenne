REBOL [
	Title: "DIG - DNS protocol"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Date: 01/09/2009
	Version: 1.0.0
]

install-protocol [
	name: 'dig
    port-id: 53
    scheme: 'udp
    verbose: 0
    
    strategy: 'round-robin		;-- alt: 'random
    dns-server:	none
	domain-size: none
	zem?: no
	dot: #"."
	value: none

	defs: [
		1	A
		2	NS
		5	CNAME
		6	SOA
		7	MB
		8	MG
		9	MR
		10	NULL
		11	WKS
		12 	PTR
		13	HINFO
		14	MINFO
		15	MX
		16	TXT
		17	ALL
	]
	
	win-get-dns: has [base local-ip out v][
		local-ip: mold read join dns:// read dns://
		
		either value? 'get-reg [
			base: "System\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
			foreach adapter list-reg/hklm base [
				if local-ip = get-reg/hklm rejoin [base #"\" adapter] "IPAddress" [
					v: get-reg/hklm rejoin [base #"\" adapter] "NameServer"
					v: parse v ","
					forall v [change v attempt [to-tuple trim v/1]]
					return head v
				]
			]
		][
			out: ""
			call/output/wait "ipconfig /all" out
			parse out [thru local-ip thru "DNS" thru #":" copy v to newline]		
			attempt [to-tuple trim v]
		]
	]

	unix-get-dns: has [conf ip][
		if exists? conf: %/etc/resolv.conf [
			parse read conf [
				any [
					thru "nameserver" copy ip to newline (
						ip: attempt [load ip]
						return ip
					)
				]
			]
		]
		none
	]
	
	either dns-server: any [
		all [value: in uniserve/shared 'dns-server get value]
		either system/version/4 = 3 [win-get-dns][unix-get-dns]
	][
		share append/only [dns-server:] dns-server
	][
		log/error "DNS server not found"
	]

	encode: func [name [string!] /local out][
		out: make binary! length? name
		repeat token parse name "." [
			insert tail out to char! length? token
			insert tail out token
		]
		insert tail out #{00}
		domain-size: length? out
		out
	]

	decode-name: func [data out /ptr /local len][
		if zero? len: to integer! data/1 [
			zem?: yes
			remove back tail out
			return next data
		]	
		either zero? len and 192 [
			len: len and 63
			insert/part tail out next data len
			insert tail out dot
			either ptr [
				decode-name/ptr at data 2 + len out
				skip data len + 2
			][
				skip data len + 1
			]
		][	
			len: to integer! (data/1 and 63) * 256 + data/2
			decode-name/ptr at head data 1 + len out
			skip data 2
		]
	]

	parse-name: func [p blk /local name][
		zem?: no
		name: make string! 32
		until [p: decode-name p name zem?]
		append blk name
		p
	]

	decode: func [data /local v b p len res type MX-rule A-rule NS-rule section-rule][
		if none? data [return -99]

		MX-rule: [
			copy v 2 skip (append blk to integer! as-binary v)
			p: (p: parse-name p blk) :p
		]
		A-rule: [
			copy v 4 skip (append blk to tuple! as-binary v)
		]
		NS-rule: [
			p: (p: parse-name p blk) :p
		]
		section-rule: [
			p: (p: parse-name p blk) :p
			copy v 2 skip (append blk type: select defs to integer! as-binary v)
			2 skip
			copy v 4 skip (append blk to integer! as-binary v)
			2 skip
			(rdata: get select [MX MX-rule A A-rule NS NS-rule] type)
			rdata
		]
		parse/all/case data [
			2 skip
			copy v 2 skip (		
				if not zero? v: 15 and to integer! as-binary v [return negate v]
				res: make block! 3
				len: copy [0 0 0]
			)
			2 skip
			3 [copy v 2 skip (len/1: to integer! as-binary v len: next len)]
			(len: head len)
			domain-size skip
			4 skip
			(blk: make block! len/1) len/1 section-rule (append/only res new-line/all/skip blk on 5)
			(blk: make block! len/2) len/2 section-rule (append/only res new-line/all/skip blk on 4)
			(blk: make block! len/3) len/3 section-rule (append/only res new-line/all/skip blk on 4)
		]
		new-line/all/skip res on 5
	]
	
	on-connected: does [
		new-insert-port server server/target
		if verbose > 1 [log/info ["connected to DNS server: " server/remote-ip]]
	]

	on-init-port: func [port url /local domain][
		port/target: port/host
		port/host: either tuple? dns-server [dns-server][
			switch strategy [
				round-robin [first head reverse dns-server]
				random		[pick dns-server random length? dns-server]
			]
		]
	]

	on-raw-received: func [data /local list pos][
		on-response data: decode as-string data	
		either integer? data [
			if verbose > 2 [log/info ["error code " mold data]]
			on-error server "unknown domain"
		][
			either empty? data/1 [
				on-error server "no MX record"
			][
				sort/skip/compare data/1 5 4
				list: extract/index data/1 5 5
				forall list [if pos: find data/3 list/1 [list/1: pick pos 4]]
				remove-each ip list: head list [none? ip] 	;-- clean up the list
				
				if verbose > 0 [log/info ["MX for " server/target ":^/" mold new-line/all list on]]
				either not empty? list [
					on-mx server list
				][
					on-error server "cannnot find MX record"
				]
			]
		]
		close-server
	]

	new-insert-port: func [port domain [string!] /local buf id][
		buf: clear #{}
		id: (to integer! now/time) // 65025

		write-server repend buf [
			to char! id / 255
			to char! id // 255
			#{01000001000000000000}
			encode domain
			#{000F0001}
		]
	]
	
	events: [
		on-response 		; [records]
		on-mx				; [ip [block!]]
		on-error			; [port code]
	]
	
	if all [value? 'debug object? :debug][debug/print ["DNS server=" dns-server]]
]
