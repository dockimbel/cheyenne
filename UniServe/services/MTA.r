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

	email-class: context [
		id: start: none
		state: [pending]
		retry: 3
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
		
		process reduce [
			any [all [from either block? from [from/2][from]] admin@noreply.com]
			reduce [dst]
			name
			-1
			none
		]
	]

	send-email: func [job [object!] mx [tuple!] dst [email!]][
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
			on-error: func [p reason][
				if verbose > 1 [log/warn ["SMTP Error: " mold reason]]
				if word? reason [reason: "mail server unreachable"]
				report-error p/job p/target reason
			]
		] compose [job: (job)]
	]

	process: func [spec [block!] /local job][
		gc-jobs
		job: make email-class [
			from:	spec/1
			to:		spec/2
			body:	spec/3
			id: 	spec/4
			report:	spec/5
			start:	now
		]
		if positive? job/id [append queue job]
		foreach dst job/to [
			open-port/with join dig:// dst/host [
				on-mx: func [p ip][		
					send-email p/job ip p/dst
				]
				on-error: func [p reason][			
					if verbose > 1 [log/error ["mx error" mold reason]]
					p/job/dst: p/dst
					report-error p/job p/dst reason
				]
			] compose [job: (job) dst: (dst)]
		]
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
			if verbose > 0 [log/info join "new request: " as-string data]
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