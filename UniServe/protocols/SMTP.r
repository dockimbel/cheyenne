REBOL [
	Title: "SMTP Async Protocol"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Version: 1.0.2
	Date: 28/02/2010
]

install-protocol [
	name: 'SMTP
	port-id: 25
	verbose: 0
	connect-retries: 4
		
	stop-at: crlf
	whoami: system/network/host
	
	alpha-num: charset [#"A" - #"Z" "0123465789"]
	
	reset: 		does [stop-at: crlf]
	fire-event: does [on-sent server]
	
	on-loop: func [su data][
		if all [
			find/part data "250" 3
			parse data: skip data 4 [some alpha-num]
		][
			append su/flags load data
		]
	]
	
	on-connected: does [
		server/timeout: 00:05		; 5 mn (RFC)
		server/user-data: context [
			state: 'ehlo
			id: random 99999999
			flags: make block! 1
		]
		stop-at: crlf
	]
	
	on-received: func [data /local su action job s][
		job: server/task/job
		su: server/user-data
		if verbose > 2 [log/info trim/tail reform [su/id ">>" as-string data]]
		if verbose > 1 [log/info [su/id " state = " su/state]]
		
		either action: select [
			helo ["220"   [["HELO " whoami crlf]] mail]
			ehlo ["220" * [["EHLO " whoami crlf]] mail]
			mail ["250" * [["MAIL FROM:<" job/from "> BODY=8BITMIME" crlf]] rcpt]
			rcpt ["250"   [["RCPT TO:<" server/task/to #">" crlf]] data]
			data ["250"   ["DATA^M^/"] body]
			body ["354"   [[%outgoing/ job/body] "^M^/.^M^/"] sent]
			sent ["250"   ["QUIT^M^/"] quit]
			quit ["221"   [fire-event] closed]
		] su/state [
			either any [action/1 = '- find/part data action/1 3][
				if action/2 = '* [
					if (length? server/locals/in-buffer) > length? data [
						on-loop su data 
						exit
					]
					action: next action
				]
				foreach s action/2 [
					s: any [all [block? s rejoin s] :s]
					if all [0 < verbose verbose < 3][log/info rejoin [su/id " request >> " s]]
					either word? s [do s][
						if verbose > 2 [log/info trim/tail reform [su/id "<<" as-string s]]
						write-server s
					]
				]
				su/state: action/3
			][
				close-server
				log/warn reform ["job:" mold job "^/*** Error:" as-string data]
				on-error server as-string data
				stop-at: none
			]
		][
			log/error reform ["unknown state" mold su/state]
		]
	]
		
	events: [
		on-sent		; [port]
		on-error	; [port reason [string!]]
	]
]



