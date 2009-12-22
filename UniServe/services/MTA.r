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
	q-file: join system/options/path %.mta-queue
	
	max-time: 2:00						;-- maximum delay for keeping reports
	;max-reports: 100					;-- maximum number of reports
	random/seed now/time/precise

	job-class: context [
		id: 		; integer! 		 - unique job id
		start: 		; date!			 - creation timestamp
		state: 		; block!		 - job processing state
		from: 		; email!		 - emitter's email address
		to: 		; block!		 - list of target email addresses
		body: 		; file!			 - name of file containing the message
		report: 	; none! | block! - customized reporting
		tasks:		; block!		 - one task per target
			none
	]
	
	task-class: context [
		to:	none	; email!		- destination
		mx:	none	; block!		- list of MX for destination domain
		retry: [	;				- retry parameters
			MX 	 [4 [5 sec]]
			SMTP [4 [5 mn]]
		]
		job: none	; object!		- reference to parent job
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
	
	clean-file: func [job][
		attempt [delete join root job/body]
	]
	
	gc-jobs: has [n][
		n: now
		remove-each job queue [
			all [
				empty? job/tasks
				max-time < difference n job/start
			]
		]
	]
	
	encode: func [s [block! email! none!]][
		any [all [block? s rejoin [s/1 " <" s/2 ">"]] s]
	]
	
	end-task: func [job task][
		remove find job/tasks task
		if empty? job/tasks [
			job/state/1: 'done
			clean-file job
		]
	]
	
	report-error: func [task msg /local job new body name from dst jr][
		job: task/job
		if job/state/3 = 'ok [change skip job/state 2 reduce ['error make block! 1]]
		if not string? msg [msg: form msg]
		repend job/state/error [task/to msg]
		end-task job task
		if negative? job/id [exit]
		
		jr: job/report
		body: join report-default/1 copy any [all [jr select jr 'body] report-default/2]
		foreach [tag new][
			"$TO$" 		[dst: any [all [jr select jr 'to] job/from]]
			"$FROM$"	[any [all [jr encode from: select jr 'from] "Mail Server <admin@noreply.com>"]]
			"$DATE$" 	[to-idate now]
			"$SUBJECT$"	[any [all [jr select jr 'subject] "###Email error reporting"]]
			"$TARGET$" 	task/to
			"$ERROR$" 	msg
		][
			replace body tag any [all [word? new get new] do new]
		]

		replace/all body lf crlf
		name: make-filename			
		write/binary root/:name body
		
		if verbose > 0 [log/info ["Sending error report to " dst]]
		
		process reduce [
			any [all [from either block? from [from/2][from]] noreply@cheyenne-server.org]
			reduce [dst]
			name
			-1
			none
		]
	]
	
	resolve-mx: func [task][
		if verbose > 0 [log/info ["Resolving MX domain " task/mx/1]]
		open-port/with join dns:// task/mx/1 [					;-- async DNS resolution
			on-resolved: func [p ip][
				if verbose > 1 [log/info ["MX resolved: " ip]]
				p/task/mx/1: ip
				send-email p/task
			]
			on-error: func [p reason][
				log/error ["cannot connect to DNS server: " mold reason]
			]
		] compose [task: (task)]
	]

	send-email: func [task [object!]][
		if not tuple? task/mx/1 [
			resolve-mx task
			exit
		]
		if verbose > 0 [log/info ["job: " task/job/id " MX: " task/mx/1]]
		
		open-port/with join smtp:// [task/mx/1 slash task/to][
			on-sent: func [p /local job][
				if verbose > 0 [log/info ["email sent to " p/task/to]]
				job: p/task/job
				remove find job/to p/task/to		;TBD: see if useful when server restarted, else remove it
				job/state/2/1: job/state/2/1 + 1
				end-task job p/task
			]
			on-error: func [p reason /local task job retry][
				if verbose > 1 [log/warn ["SMTP Error: " form reason]]
				task: p/task
				retry: task/retry
				either any [
					zero? retry/smtp/1: retry/smtp/1 - 1
					all [string? reason #"4" <> reason/1]		;-- temp failure, possible greylisting
				][
					if verbose > 1 [log/info ["job " task/job/id " failed, sending report"]]
					if word? reason [reason: "mail server unreachable"]
					report-error task reason
				][
					either word? reason [
						if verbose > 2 [log/info "trying with another MX"]
						retry/mx/1: retry/mx/1 - 1				;-- blame MX server
						retry/smtp/1: task-class/retry/smtp/1	;-- reset SMTP failure counter to default
						
						either empty? task/mx: next task/mx [
							scheduler/plan compose/deep [		;-- try again from beginning later
								in (retry/smtp/2) do [uniserve/services/mta/get-mx (task)]	 
							]
						][
							send-email task 					;-- try with next MX at once
						]
					][
						if verbose > 2 [log/info ["retrying with same MX in " mold/only retry/smtp/2]]
						scheduler/plan compose/deep [			;-- try again later
							in (retry/smtp/2) do [uniserve/services/mta/send-email (task)] 
						]
					]
				]
				
			]
		] compose [task: (task)]
	]
	
	get-mx: func [task][
		open-port/with join dig:// task/to/host [
			on-mx: func [p list][
				p/task/mx: list
				send-email p/task								;-- got MX, now send email
			]
			on-error: func [p reason /local retry][			
				if verbose > 1 [log/warn ["MX error: " form reason]]
				retry: p/task
				either any [
					string? reason
					zero? retry/mx/1: retry/mx/1 - 1 			;-- count failures
				][
					if verbose > 1 [
						either positive? p/task/job/id [
							log/info reform ["job" p/task/job/id "failed, sending report"]
						][
							log/warn reform ["sending report to" task/to "failed...giving up"]
						]
					]
					report-error p/task reason					;-- max retries reached or unknown domain
				][													
					if verbose > 2 [log/info "Retrying MX query on DNS server(s)"]
					scheduler/plan compose/deep [				;-- try again later
						in (retry/mx/2) do [uniserve/services/mta/get-mx (p/task)]
					]
				]
			]
		] compose [task: (task)]
	]
	
	split: func [parent /local list][
		list: copy parent/to		
		forall list [
			list/1: make task-class [
				to: list/1
				retry: copy/deep retry
				job: parent
			]
		]
		parent/tasks: head list
	]

	process: func [spec [block!] /local job][
		gc-jobs
		job: make job-class [
			from:	spec/1
			to:		spec/2
			body:	spec/3
			id: 	spec/4
			report:	spec/5
			state:	reduce ['pending 0x1 * length? spec/2 'ok]
			start:	now
		]
		if positive? job/id [append queue job]
		foreach task split job [get-mx task]					;-- init sending process
	]

	get-info?: func [id [integer!] /local job][
		mold/all either job: foreach j queue [if j/id = id [break/return j]][
			if job/state/1 = 'done [remove find queue job]
			job/state
		][
			none
		]
	]
	
	on-quit: has [flags][	
		if all [
			not empty? queue
			attempt [flags: uniserve/shared/config/globals/persist]
			find flags 'mail-queue
		][
			foreach job queue [									;-- workaround cycles issues
				foreach task job/tasks [if not empty? job/tasks [task/job: none]]
			]
			attempt [write q-file mold/all queue]
		]	
	]

	on-started: has [pid][
		if cheyenne/port-id [append q-file join "-" cheyenne/port-id/1]
		if all [
			exists? q-file
			queue: attempt [load q-file]
		][
			delete q-file
			foreach job queue [
				if not empty? job/tasks [
					foreach task job/tasks [				
						task/job: job							;-- link back to parent
						get-mx task
					] 
				]
			]
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