REBOL [
	Title: "CGI handler"
	Author: "Nenad Rakocevic"
	Version: 1.2.0
	Date: 17/11/2010
]

install-module [
	name: 'CGI

	output: make string! 65536
	err-log: make string! 2048
	local-name: read dns://
	save-path: system/options/path
	empty: ""
	ws: charset "^/^M^- "
	
	vars: compose/deep [
		sys [
			"SERVER_ADDR"		(form any [read join dns:// local-name empty])
			"SERVER_SOFTWARE"	"Cheyenne/1.0"
			"SERVER_NAME"		(local-name)
			"SERVER_PROTOCOL"	"HTTP/1.1"
			"GATEWAY_INTERFACE"	"CGI/1.1"
		]
		cgi [
			"AUTH_TYPE"
			"CONTENT_LENGTH"
			"CONTENT_TYPE"
			"PATH_INFO"
			"PATH_TRANSLATED"
			"QUERY_STRING"
			"REMOTE_ADDR"
			"REMOTE_HOST"
			"REMOTE_IDENT"
			"REMOTE_USER"
			"REQUEST_METHOD"
			"SCRIPT_NAME"
			"SERVER_PORT"
		]
		apache [
			"DOCUMENT_ROOT"
			"REMOTE_PORT"
			"REQUEST_URI"
			"SCRIPT_FILENAME"
		]
		unsupported [
			"DATE_GMT"
			"DATE_LOCAL"
			"DOCUMENT_NAME"
			"DOCUMENT_PATH_INFO"
			"DOCUMENT_URI"
			"HTTPS"
			"LAST_MODIFIED"
			"QUERY_STRING_UNESCAPED"
			"REDIRECT_HANDLER"
			"REDIRECT_QUERY_STRING"
			"REDIRECT_REMOTE_USER"
			"REDIRECT_STATUS"
			"REDIRECT_URL"
			"SCRIPT_URI"
			"SERVER_ADMIN"
			"SERVER_SIGNATURE"
			"UNIQUE_ID"
			"USER_NAME"
			"TZ"
		]
	]
	
	OS: context [
		set 'set-env none
		libc: _setenv: body: none
		cgi?: yes
		
		either not find system/components 'library [
			log/error "/Library component missing, can't setup CGI module"
			cgi?: no
		][
			switch/default system/version/4 [
				2 [ 									;-- OS X
					libc: load/library %libc.dylib
					_setenv: make routine! [
						name		[string!]
						value		[string!]
						overwrite	[integer!]
						return: 	[integer!]
					] libc "setenv"
					body: [_setenv name value 1]
				]
				3 [										;-- Windows
					do-cache %misc/call.r
					set 'call :win-call
				]
			][											;-- UNIX
				either any [
					exists? libc: %libc.so.6
					exists? libc: %/lib32/libc.so.6
					exists? libc: %/lib/libc.so.6
					exists? libc: %/System/Index/lib/libc.so.6  ; GoboLinux package
					exists? libc: %/system/index/framework/libraries/libc.so.6  ; Syllable
					exists? libc: %/lib/libc.so.5
				][
					libc: load/library libc
					_setenv: make routine! [
						name		[string!]
						value		[string!]
						overwrite	[integer!]
						return: 	[integer!]
					] libc "setenv"
					body: [_setenv name value 1]
				][
					log/error "Can't find any suitable C library for CGI setup"
					cgi?: no
				]
			]
			if body [
				set 'set-env func [name [string!] value [string!]] body
			]
			foreach [name value] vars/sys [
				set-env name value
			]
		]
	]
	
	set 'halt set 'q set 'quit does [throw 'force-quit]
	set 'input ""
	
	set 'cgi-read-io func [p buf len][
		insert tail buf len: copy/part input len
		input: skip input len: length? len
		len
	]
	;-- Patch READ-CGI 
	parse second :read-cgi rule: [
		any [s: 'read-io (change s 'cgi-read-io) | into rule | skip]
	]
	
	cgi-prin:  func [data][insert tail output reform data]
	cgi-print: func [data][insert tail output join reform data newline]
	cgi-probe: func [data][insert tail output mold data data]
	
	cgi-print-funcs: reduce [:cgi-prin :cgi-print :cgi-probe]
	saved-print-funcs: reduce [:prin :print :probe]
	print-funcs: [prin print probe]

	safe-exec: func [code [block!] bytes /local ret-val err-obj type id desc][
		set 'input bytes
		set print-funcs cgi-print-funcs
		if error? set/any 'ret-val try [catch code][
			err-obj: disarm ret-val
			type: err-obj/type
			id:   err-obj/id
			arg1: err-obj/arg1
			arg2: err-obj/arg2
			arg3: err-obj/arg3
			desc: reduce system/error/:type/:id
			prin "Content-Type: text/html^/^/"
			prin {
<HTML>
	<HEAD>
		<TITLE>
			REBOL Error Trapped
		</TITLE>
	</HEAD>
	<BODY>
		<BR>
		<CENTER>
		<H2>&gt; Trapped Error &lt;</H2><BR>
		<TABLE border="1">
		<TR><TD align="right"><FONT face="Arial"><B>Error Code :</B></FONT></TD>
		<TD align="left"><FONT face="Arial">}prin mold err-obj/code prin{</FONT></TD></TR>
		<TR><TD align="right"><FONT face="Arial"><B>Description :</B></FONT></TD>
		<TD align="left"><FONT face="Arial">}prin ["<I>"type " error ! </I><BR>"desc] prin{</FONT></TD></TR>
		<TR><TD align="right"><FONT face="Arial"><B>Near :</B></FONT></TD>
		<TD align="left"><FONT face="Arial">}prin mold err-obj/near prin{</FONT></TD></TR>
		<TR><TD align="right"><FONT face="Arial"><B>Where :</B></FONT></TD>
		<TD align="left"><FONT face="Arial">}prin mold err-obj/where prin{</FONT></TD></TR>
		</TABLE>
		</CENTER>
	</BODY>
</HTML>
			}
		]
		set print-funcs saved-print-funcs
	]
	
	header-error-page:	{Content-type: text/plain
	
	Error in CGI : shebang #! header not found!
	}
	
	http-encode: func [data][
		join "HTTP_" uppercase replace/all form data #"-" #"_"	;-- not worth optimizing
	]
	
	reset-env-vars: does [
		foreach var vars/cgi 	[set-env var empty]
		foreach var vars/apache [set-env var empty]
		foreach [name value] system/options/cgi/other-headers [
			set-env name empty
		]
	]
	
	set-env-vars: func [data /local var soc root][
		soc: system/options/cgi
		root: either slash = first data/cfg/root-dir [
			data/cfg/root-dir
		][
			join system/options/path data/cfg/root-dir
		]

		var: vars/cgi
		set-env	var/1	empty								; AUTH_TYPE
		set-env	var/2	any [soc/content-length "0"]		; CONTENT_LENGTH
		set-env	var/3	any [soc/content-type empty]		; CONTENT_TYPE
		set-env	var/4	soc/path-info						; PATH_INFO
		set-env	var/5	soc/path-translated					; PATH_TRANSLATED
		set-env	var/6	soc/query-string					; QUERY_STRING
		set-env	var/7	soc/remote-addr						; REMOTE_ADDR
		set-env var/8	empty								; REMOTE_HOST
		set-env	var/9	empty								; REMOTE_IDENT
		set-env	var/10	empty								; REMOTE_USER
		set-env	var/11	soc/request-method					; REQUEST_METHOD
		set-env	var/12	soc/script-name						; SCRIPT_NAME
		set-env	var/13	soc/server-port						; SERVER_PORT
		
		var: vars/apache
		set-env	var/1	to-local-file root 					; DOCUMENT_ROOT
		;set-env var/2	empty								; REMOTE_PORT
		set-env	var/3	data/in/url							; REQUEST_URI
		set-env	var/4	to-local-file join root soc/script-name ; SCRIPT_FILENAME
		
		foreach [name value] soc/other-headers [
			set-env name value
		]
	]
	
	decode-all: func [data /local soc][
		soc: system/options/cgi
		
		soc/server-software: 	"Cheyenne/1.0"
		soc/server-name: 		any [select data/in/headers 'Host local-name]
		soc/gateway-interface: "CGI/1.1"
		soc/server-protocol: 	"HTTP/1.1"
		soc/server-port: 		form data/port
		soc/request-method: 	form any [data/in/method empty]
		soc/path-info:			join data/in/path data/in/target
		soc/script-name: 		any [data/in/script-name join data/in/path data/in/target]
		soc/path-translated: 	to-local-file join data/cfg/root-dir soc/script-name
		soc/query-string: 		any [data/in/arg empty]
		soc/remote-host: 		none
		soc/remote-addr: 		form data/ip
		soc/auth-type: 			none
		soc/remote-user: 		none
		soc/remote-ident: 		none
		soc/content-type: 		select data/in/headers 'Content-Type
		soc/content-length: 	any [all [data/in/content to-string length? data/in/content] none]
		soc/other-headers: 		make block! 20
		
		foreach [name value] data/in/headers [
			insert tail soc/other-headers http-encode name
			insert tail soc/other-headers value
		]	
	]
	
	on-task-received: func [data /local file port header script cmd][
		;-- this function needs full refactoring for readability
		data: reduce load data
		decode-all data		
		clear output
		clear err-log
		
		file: join data/cfg/root-dir [
			data/in/path
			data/in/target
		]
		port: open/read/direct/binary file
		header: as-string copy/part port 512
		parse/all header [any [script: "REBOL" any ws #"[" break | skip]]
	
		either all [
			string? script
			not empty? script
			find data/cfg 'fast-rebol-cgi
		][	
			append script copy port			
			close port
			system/options/script: file
			change-dir first split-path file	
			set 'input any [data/in/content ""]
			safe-exec load as-string script input
			script: none
			change-dir save-path		
			result: output
		][		
			unless OS/cgi? [
				result: "CGI Error: can't run non-REBOL CGI scripts!"
				exit
			]
			either "#!" = copy/part header 2 [
				cmd: copy/part skip header 2 find header newline
				cmd: to-local-file trim/tail cmd
				append cmd #" "
				append cmd to-local-file file
			][
				cmd: form file
			]
			close port
			
			set-env-vars data
			either data/in/content [
				call/output/error/wait/input
					cmd
					output
					err-log
					data/in/content
			][
				call/output/error/wait
					cmd
					output
					err-log
			]
			unless empty? err-log [log/info ["Error:" trim/tail err-log]]
			result: output
			reset-env-vars
		]
		header: port: data: none
	]
]
