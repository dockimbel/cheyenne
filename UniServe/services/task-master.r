REBOL [
	Title: "Uniserve: task-master service"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Version: 1.4.0
	Date: 02/01/2009
	History: [
		1.4.0 - 02/01/2009 {
			o 'no-delay mode removed and replaced by 'keep-alive mode
			o 'resurrect? property added
			o fix a long standing bug in queued job module mismatching
			o 'on-reset callback added to allow restarting of all worker processes
			o minor clode cleanup
		}
		1.3.0 - 06/06/2006 {
			o Added 'locals argument to all 'on-task-* callbacks
		}
		1.2.0 - 17/01/2006 {
			o Added 'part message support triggering the new 'on-task-part callback.
		}
		1.1.1 - 23/03/2005 {
			o Cleaner handling of errors for 'on-task-failed invocation.
		}
		1.1.0 - 01/02/2005 {
			o Client/user-data added to the saved context for each task.
		}
	]
]

install-service [
	name: 'task-master
	port-id: 9799
	;hidden: yes
	verbose: 0
	
	bg-process: %services/task-master/task-handler.r
	pool-list: make block! 16
	obj: len: none
	queue: make block! 100
	worker-args: none

	share [
		pool-start: 2	; number of helper process when Uniserve starts
		pool-max: 	4	; maximum number of helper process
		pool-count: 0	; read-only - ** do not change it **!!
		job-max: 	100	; max size of the waiting jobs queue
		resurrect?:	yes	; create a new process when one die
		do-task: func [data service /save locals][
			process-task data service service/client any [locals none]		
		]
	]

	task: context [
		busy: no
		kill?: no
		ctx: none
	]

	fork: has [cmd][
		if verbose > 0 [log/info "launching new slave"]
		shared/pool-count: shared/pool-count + 1
		cmd: mold either value? 'uniserve-path [
			rejoin [uniserve-path slash bg-process]
		][
			bg-process
		]
		launch* either encap? [worker-args][reform [cmd worker-args]]
	]	
	
	send-job: func [port data][
		len: debase/base to-hex length? data: mold data 16
		insert data len
		write-client/with data port
	]
	
	process-task: func [data server port locals /local wud obj][
		foreach worker pool-list [
			wud: worker/user-data
			if not wud/busy [
				if verbose > 0 [
					log/info join "new task affected using module: " server/module
				]
				send-job worker reduce [server/name server/module data]
				wud/busy: yes
				wud/ctx: reduce [server port locals]
				return wud
			]
		]
		;-- Available worker not found, create a new one if allowed
		if any [
			zero? shared/pool-max
			shared/pool-max > shared/pool-count 
		][fork]
		
		;-- Queue job until a free worker picks it
		either shared/job-max > length? queue  [
			if verbose > 0 [log/info "queuing job"]
			repend/only queue [copy/deep data server port locals server/module]
		][
			if in obj: client/user-data/ctx/1 'on-task-failed [
				obj/on-task-failed 'overload "maximum workers number reached"
			]
		]
	]
	
	on-reset: does [
		if verbose > 0 [log/info "resetting all workers"]
		foreach worker copy pool-list [		;-- list copied because it is modified by 'close-peer
			either worker/user-data/busy [
				worker/user-data/kill?: yes
			][
				;close-peer/force/with worker
				uniserve/close-connection/bypass worker
				remove find pool-list worker
				shared/pool-count: shared/pool-count - 1
			]
		]
		if integer? shared/pool-start [loop shared/pool-start [fork]]
	]
	
	on-started: has [file][
		worker-args: reform [
			"-worker" mold any [in uniserve/shared 'server-ports port-id]		;TBD: fix shared object issues
		]
		if not encap? [
			append worker-args reform [" -up" mold uniserve-path]
			if value? 'modules-path [
				append worker-args reform [" -mp" mold modules-path]
			]
			if all [
				uniserve/shared
				file: uniserve/shared/conf-file 
			][		
				append worker-args reform [" -cf" mold file]
			]
		]
		if integer? shared/pool-start [loop shared/pool-start [fork]]
	]

	on-new-client: has [job][
		if client/remote-ip <> 127.0.0.1 [close-client exit]
		set-modes client [keep-alive: on]
		client/timeout: 15
		client/user-data: make task []
		append pool-list :client
		stop-at: 4
		if verbose > 0 [log/info "new slave process connected"]
		if not empty? queue [
			job: queue/1
			send-job client reduce [job/2/name job/5 job/1]
			client/user-data/busy: yes
			client/user-data/ctx: reduce [job/2 job/3 job/4]
			remove queue
			if verbose > 0 [log/info "new slave got job"]
		]
	]
	
	on-close-client: does [
		remove find pool-list :client
		shared/pool-count: shared/pool-count - 1
		if client/user-data/busy [
			if in obj: client/user-data/ctx/1 'on-task-failed [
				obj/on-task-failed 'error client/user-data/ctx/3
			]
		]
		if verbose > 0 [log/info "slave process closed"]

		if all [
			not zero? shared/pool-max
			shared/resurrect?
			shared/pool-max > shared/pool-count 
		][fork]
	]
	
	
	on-received: func [data /local job svc sav-client locals][
		either stop-at = 4 [
			if verbose > 1 [log/info "header received"]
			stop-at: to integer! copy data
		][
			if verbose > 1 [log/info "body received"]
			ctx: client/user-data/ctx
			svc: ctx/1
			sav-client: svc/client
			svc/client: svc/peer: ctx/2				; restore client port
			locals: ctx/3
			data: first load/all as-string data
			switch first data [
				ok		[svc/on-task-done data/2 locals]
				part	[
					if in svc 'on-task-part [svc/on-task-part data/2 locals]
					svc/client: svc/peer: sav-client
					stop-at: 4
					exit
				]
				error	[			
					if in svc 'on-task-failed [
						svc/on-task-failed first reduce next data locals
					]
				]
			]
			stop-at: 4
			if client/user-data/kill? [
				close-client
				exit
			]
			svc/client: svc/peer: sav-client
			either empty? queue [
				client/user-data/busy: no
				client/user-data/ctx: none
				if zero? shared/pool-max [close-client]
			][
				job: queue/1
				send-job client reduce [job/2/name job/5 job/1]
				client/user-data/ctx: reduce [job/2 job/3 job/4]
				remove queue
				if verbose > 0 [log/info "no wait-state slave reuse"]
			]
		]
	]
]