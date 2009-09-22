REBOL [
	Title: "Mail Transfer Agent service"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Date: 02/09/2009
	Version: 1.0.0
]

install-service [
	name: 'MTA
	port-id: 9803
	verbose: 0
	
	queue: make block! 8
	root: join what-dir %outgoing/
	max-time: 01:00						;-- maximum delay for keeping reports
	max-reports: 100					;-- maximum number of reports
	random/seed now/time/precise

	job-class: context [
		id: start: none
		state: [pending]
		retry: [mx [4 [5 sec]] smtp [4 [15 mn]]]
		from: to: body: report: none
	]
	
	report-default: [
{To: $TO$
From: $FROM$
Date: $DATE$
Subject: $SUBJECT$
MIME-Version: 1.0
Content-Type: text/plain; charset="ISO-8859-1"
Content-Transfer-Encoding: 8bit

}
{This is an automated technical report, please do not reply.

Message: error trying to send email to $TARGET$
Cause:   $ERROR$
}
]
	make-filename: has [name][
		name: make file! 8
		until [
			clear name
			loop 8 [append name #"`" + random 26]
			not exists? root/:name
		]
		name
	]
	
	try-clean-file: func [job][
		if job/to = intersect job/to job/state [
			attempt [delete join root job/body]
		]
	]
	
	gc-jobs: has [n][
		if max-reports < length? queue [
			remove/part queue (length? queue) - maxreports
		]
		n: now
		remove-each job queue [max-time < difference n job/start]
	]
	
	encode: func [s [block! email! none!]][
		any [all [block? s rejoin [s/1 " <" s/2 ">, "]] s]
	]	
	
	report-error: func [job target msg /local new body name from dst jr][
		job/state/1: 'error
		if not string? msg [msg: form msg]
		repend job/state [to email! target msg]		
		try-clean-file job
		if negative? job/id [exit]
		
		jr: job/report
		body: join report-default/1 copy any [all [jr select jr 'body] report-default/2]
		foreach [tag new][
			"$TO$" 		[dst: any [all [jr select jr 'to] job/from]]
			"$FROM$"	[any [all [jr encode from: select jr 'from] "Mail Server <admin@noreply.com>"]]
			"$DATE$" 	[to-idate now]
			"$SUBJECT$"	[any [all [jr select jr 'subject] "###Email error reporting"]]
			"$TARGET$" 	target
			"$ERROR$" 	msg
		][
			replace body tag any [all [block? new do new] get new]
		]

		replace/all body lf crlf
		name: make-filename			
		write/binary root/:name body
		
		if verbose > 0 [log/info ["Sending error report to " dst]]
		
		process reduce [
			any [all [from either block? from [from/2][from]] admin@noreply.com]
			reduce [dst]
			name
			-1
			none
		]
	]

	send-email: func [job [object!] mx [tuple!] dst [email!]][
		if verbose > 0 [log/info ["job: " job/id " MX: " mx]]
		
		open-port/with join smtp:// [mx slash dst][
			on-sent: func [p /local job][
				if verbose > 0 [log/info ["email sent to " p/target]]
				job: p/job
				remove find job/to to email! p/target
				if all [empty? job/to job/state/1 = 'pending][
					job/state/1: 'done
				]			
				try-clean-file job
			]
			on-error: func [p reason /local retry][
				if verbose > 1 [log/warn ["SMTP Error: " form reason]]
				retry: p/job/retry
				either any [
					zero? retry/smtp/1: retry/smtp/1 - 1
					all [string? reason #"4" <> reason/1]		;-- temp failure, possible greylisting
				][
					if verbose > 1 [log/info ["job " p/job/id " failed, sending report"]]
					if word? reason [reason: "mail server unreachable"]
					report-error p/job p/target reason
				][
					either word? reason [
						if verbose > 2 [log/info "trying with another MX"]
						retry/smtp/1: 4							;-- reset SMTP failure counter
						get-mx to-email p/target p/job			;-- try with another MX at once
					][
						if verbose > 2 [log/info ["retrying with same MX in " mold/only retry/smtp/2]]
						scheduler/plan compose/deep [
							in (retry/smtp/2) do [send-email (p/job) (p/host) (to-email p/target)] ;-- try again later
						]
					]
				]
				
			]
		] compose [job: (job)]
	]
	
	get-mx: func [dst [email!] job][
		open-port/with join dig:// dst/host [
			on-mx: func [p ip][
				send-email p/job ip p/dst						;-- got MX, now send email
			]
			on-error: func [p reason /local retry][			
				if verbose > 1 [log/warn ["MX error: " form reason]]
				retry: p/job
				either any [
					string? reason
					zero? retry/mx/1: retry/mx/1 - 1 			;-- count failures
				][
					if verbose > 1 [
						either positive? p/job/id [
							log/info reform ["job" p/job/id "failed, sending report"]
						][
							log/warn reform ["sending report to" p/dst "failed...giving up"]
						]
					]
					report-error p/job p/dst reason				;-- max retries reached or unknown domain
				][													
					if verbose > 2 [log/info "Retrying MX query on DNS server(s)"]
					scheduler/plan compose/deep [
						in (retry/mx/2) do [get-mx (to-email p/dst) (p/job)]	;-- try again later
					]
				]
			]
		] compose [job: (job) dst: (dst)]
	]

	process: func [spec [block!] /local job][
		gc-jobs
		job: make job-class [
			from:	spec/1
			to:		spec/2
			body:	spec/3
			id: 	spec/4
			report:	spec/5
			start:	now
		]
		if positive? job/id [append queue job]
		foreach dst job/to [get-mx dst job]		;-- init sending process
	]

	get-info?: func [id [integer!] /local job][
		mold/all all [
			job: foreach j queue [if j/id = id [break/return j]]
			job/state
		]
	]

	on-new-client: does [
		if client/remote-ip <> 127.0.0.1 [close-client]
		stop-at: 4
	]

	on-received: func [data][
		 either client/user-data = 'head [
			if verbose > 0 [log/info ["new request: " as-string data]]
			either data/1 = #"I" [
				write-client get-info? to integer! as-string next data
				close-client
			][
				process load as-string data
			]
			client/user-data: none
			stop-at: 4
		][
			client/user-data: 'head
			stop-at: to integer! data
		]
	]
]