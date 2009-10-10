REBOL [
	Title: "Scheduler"
	Purpose: "Scheduler library for REBOL"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Copyright: "2009 SOFTINNOV"
	Email: nr@softinnov.com
	Date: 26/08/2009
	Version: 0.9.0
	Web: http://softinnov.org/rebol/scheduler.shtml
	License: "BSD - see %LICENCE.txt file"
]
		
scheduler: context [
	label: mult: unit: n: allow: forbid: on-day: ts: from: times: job: err:
	type: _s: _e: s: e: value: none
	;-- every word put before value: will be erased by 'reset function
	
	name: 'scheduler
	verbose: 1
	
	jobs:  make block! 8
	queue: make block! 1
	spwl:  system/ports/wait-list
	flag-exit: off
	
	log: func [msg /warn /error /info /fatal][print msg]	;-- default log action
	
	get-now: has [n][n: now n/zone: 0:0 n]
	
	exec: func [spec /local action res][	; TBD: catch errors + log in file
		action: select spec 'action
		switch type?/word action [
			url!   	  [read action]
			block! 	  [do action]
			file! 	  [do action]
			function! [do :action]
			word!	  [do get :action]
		]
	]
	
	set 'do-events wait: does [
		flag-exit: off
		while [none? res: system/words/wait []][
			on-timer
			if any [flag-exit empty? jobs][exit]
		]
	]
	
	start: does [update-sys-timer]
	stop:  does [remove find spwl time!]
	
	on-timer: has [task job][
		task: queue/1
		job: back find/only jobs task
		remove queue
		task/last: get-now
		if verbose > 0 [log/info ["firing event " mold any [task/name task/source]]]
		exec task	
		if any [
			task/at
			all [task/repeat zero? task/repeat: task/repeat - 1]
			none? job/1: next-event? task
		][
			remove/part job 2
		]
		update-sys-timer
	]
	
	update-sys-timer: has [timer][
		sort/skip jobs 2
		remove find spwl time!	
		if not empty? jobs [
			append/only queue jobs/2
			append spwl difference jobs/1 get-now
		]
	]
	
	reset-series: func [s [series!] len [integer!]][head clear skip s len]
	
	reset-locals: has [list][
		clear next find list: first self 'value
		set next bind list self err: none
	]
	
	allowed?: func [spec [block!] time [time!]][
		foreach v spec [
			if any [
				all [block? v v/1 <= time time <= v/2]
				v = time
			][return yes]
		]
		no
	]
	
	search-event: func [spec new /short /local tests offset next-new sa sf u list][
		tests: clear []
		sa: spec/allow
		sf: spec/forbid
		u:  spec/unit

		;-- constraints compilation --
		foreach [cond test][
			[sa select sa 'cal-days] 	[find sa/cal-days  new/day]
			[sa select sa 'week-days]	[find sa/week-days new/weekday]
			[sa select sa 'months] 		[find sa/months    new/month]
			[sa select sa 'time] 		[allowed? sa/time  new/time]
			[sf select sf 'cal-days] 	[not find sf/cal-days  new/day]
			[sf select sf 'week-days] 	[not find sf/week-days new/weekday]
			[sf select sf 'months] 		[not find sf/months    new/month]
			[sf select sf 'time] 		[not allowed? sf/time  new/time]
		][
			if all cond [append tests test]
		]
		offset: any [spec/multiple 1]
		next-new: either find [day month] u [
			[new/:u: new/:u + offset]
		][
			offset: offset * select [hour 1:0 minute 0:1 second 0:0:1] u
			[new/time: new/time + offset]
		]
		if short [do next-new return new]
		
		;-- evaluation --
		loop select [
			second	60
			minute	60
			hour	24
			day		366		; account for leap years
			month	12
		] u [	
			do next-new				
			if all tests [return new]			
		]
		make error! rejoin ["can't find next event for rule " mold spec/source]
	]

	set-datetime: func [src [date! time!] dst [date!]][
		if date? src [
			dst/date: src/date
			if src/time [dst/time: src/time]
			dst/zone: 0:0
		]
		if time? src [dst/time: src]
		dst
	]
	
	next-event?: func [spec [block!] /local new][
		if spec/repeat = 0 [return none]
		if spec/at = 'in [
			spec/at: search-event/short spec get-now
		]
		either any [date? spec/at none? spec/unit][
			;-- AT --
			new: get-now
			new: set-datetime spec/at new
		][
			;-- EVERY --
			new: any [spec/last get-now]
			if all [not spec/last spec/from][new: set-datetime spec/from new]
			if spec/at [new/time: spec/at]
			if spec/unit = 'month [
				new/day: any [
					spec/on
					all [date? spec/from spec/from/day]
					1
				]
			]
			new: search-event spec new
		]		
		new
	]
	
	store-job: has [record al src][
		src: copy/part _s _e
		if all [
			block? allow
			block? forbid
			not empty? intersect allow forbid
		][
			make error! rejoin ["bad or sub-optimal specifications for" mold src]
		]
		record: reduce [
			'name		all [label to word! label]
			'multiple	mult
			'unit		unit
			'allow		allow
			'forbid		forbid
			'on			on-day
			'at			ts
			'from		from
			'repeat		times
			'action 	job
			'last		none
			'log?		yes
			'debug? 	no
			'source		src
		]
		;probe new-line/all copy/part record 20 off
		repend jobs [next-event? record record]
	]
	
	blockify: func [name type /local blk][
		if not block? get name [set name make block! 1]
		name: get name
		if not blk: select name type [
			repend name [type blk: make block! 1]
		]
		blk
	]
	
	expand: func [name type s e /local list][
		list: blockify name type
		s: -1 + to integer! form s
		e: 1 + to integer! form e
		repeat c min e - s 60 [insert list e - c]
	]
	
	store: func [name type value /only /local list][
		list: blockify name type
		if issue? value [value: to integer! form value]
		either only [append/only list value][append list value]
	]
	
	cal-days: [set n integer!]
	
	week-days: [
		  ['Monday		| 'Mon]	(n: 1)
		| ['Tuesday		| 'Tue]	(n: 2)
		| ['Wednesday 	| 'Wed]	(n: 3)
		| ['Thursday	| 'Thu]	(n: 4)
		| ['Friday		| 'Fri]	(n: 5)
		| ['Saturday	| 'Sat]	(n: 6)
		| ['Sunday		| 'Sun]	(n: 7)
	]
	months: [
		  ['January		| 'Jan]	(n: 1)
		| ['February	| 'Feb]	(n: 2)
		| ['March		| 'Mar]	(n: 3)
		| ['April		| 'Apr]	(n: 4)
		| ['May			| 'May]	(n: 5)
		| ['June		| 'Jun]	(n: 6)
		| ['July		| 'Jul]	(n: 7)
		| ['August		| 'Aug]	(n: 8)
		| ['September	| 'Sep]	(n: 9)
		| ['October		| 'Oct]	(n: 10)
		| ['November	| 'Nov]	(n: 11)
		| ['December	| 'Dec]	(n: 12)
	]
	
	delays: [
		  ['seconds | 'second	| 'sec | 's] (unit: 'second)
		| ['minutes | 'minute 	| 'mn]		 (unit: 'minute)
		| ['hours   | 'hour   	| 'h] 		 (unit: 'hour)
		| ['days    | 'day	   	| 'd] 		 (unit: 'day)
		| ['weeks   | 'week   	| 'w] 		 (unit: 'day mult: 7 * any [mult 1])
		| ['months  | 'month	| 'm] 		 (unit: 'month) opt rule-on-day
	   ;| 'last-day-of-month 				 (unit: 'ldom)	; unsupported	use every -1, -2...??
	   ;| 'day-of-year 	  					 (unit: 'doy)	; unsupported
	]
	
	rule-on-day: ['on set value issue! (unit: 'day store 'allow 'cal-days value)]
	
	week-months: [
		week-days 	(unit: 'day store type 'week-days n)
		| months 	(unit: any [unit 'month] store type 'months n)
		  opt rule-on-day
	]
	
	restriction: [
		set s issue! '- set e issue! (expand type 'cal-days s e)
		| set s time! '- set e time! (store/only type 'time reduce [s e])
		| set value time! 			 (store type 'time value) 
		| set value issue! 			 (unit: 'day store type 'cal-days value) 
		| week-months
	]
	
	restrictions: [restriction | into [some restriction]]
	
	times-rule: [set times integer! ['times | 'time]]
	
	every-rule: [
		opt [set mult integer!]
		[
			(type: 'allow) restrictions opt rule-on-day
			| [delays | (type: 'allow) week-months] opt [(type: 'allow) restrictions]
		]
		1 4 [
			opt ['not (type: 'forbid) restrictions]
			opt ['from set from [date! | time!]]
			opt ['at set ts [date! | time!]]
			opt times-rule
		]
	]

	dialect: [
		any [
			(reset-locals) err: _s:
			opt [set label set-word!]
			[
				'at [set ts [date! | time!]]
				| 'in set mult integer! delays (ts: 'in)
				| 'every every-rule
			]
			'do set job [file! | url! | block! | word! | function!] _e: (store-job)
		]
	]
	
	digits: charset "0123456789"
	
	pre-process: func [src [string!] /local s e v fix out][
		fix: [e: (s: change/part s v e) :s]		
		parse/all src [
			any [
				s: "1st"   (v: "#1")  fix
				| "2nd"    (v: "#2")  fix
				| "3rd"    (v: "#3")  fix
				| copy v 1 3 digits [
					"th"   (v: join "#" v) fix
					| "s"  (v: join v " s")  fix
					| "mn" (v: join v " mn") fix
					| "h"  (v: join v " h")  fix
					| "w"  (v: join v " w")  fix
					| "m"  (v: join v " m")  fix
				]
				| skip
			]
		]		
		if none? out: attempt [load/all src][
			make error! join "Scheduler input syntax error in: " src
		]	
		out
	]

	plan: func [spec [block! string!] /new][
		if new [reset]
		if string? spec [spec: pre-process spec]
		
		if not parse copy/deep spec dialect [
			log/error ["Error parsing at rule:" mold copy/part err 10]
		]	
		update-sys-timer
	]
	
	reset: does [
		clear jobs
		clear queue
		remove find spwl time!
	]
	
	delete: func [name [word!] /local job][
		job: jobs
		forskip job 2 [
			if job/2/name = name [
				remove/part job 2
				return true
			]
		]
		make error! reform ["job" mold name "not found!"]
	]
]


