REBOL [
    Title: "Log Object Definition"
    Purpose: "Provides an easy way to log messages to screen/file"
    File:  %log.r
    Version: 1.1.0
]

logger: context [
	level: 'screen	; 'screen, 'file, 'csv, 'both, none
	file: %activity
	file.log: join file %.log
	file.csv: join file %.csv
	col: #":"
	zero: #"0"
	dot: #"."
	
	notify: func [msg module [word!] type [word!] /local out time off][
		if none? level [exit]
		out: msg
		if block? out [out: rejoin out]
		if not string? out [out: mold out]
		uppercase/part out 1
		out: reform switch type [
			warn  [["# Warning in" mold reduce [module] ":" out "!"]]
			error [["## Error in" mold reduce [module] ":" out "!"]]
			fatal [["### FATAL in" mold reduce [module] ":" out "!"]]
			info  [[mold reduce [module] out]]
		]
		time: mold now/time/precise
		off: pick [-3 -6] system/version/4 = 3
		if col = time/2 [insert time zero]
		if dot = pick tail time off [insert tail time zero]
		
		out: rejoin [now/day "/" now/month "-" time  "-" out]
		switch level [	
			screen	[system/words/print out]		
			file	[write/append file.log append out newline]
			both [
				system/words/print out
				write/append file.log append out newline
			]
			csv [
				switch type [
					warn	[type: 'Warning]
					error	[type: 'Error]
					info	[type: 'Info]
				]
				write/append file.csv rejoin [
					mold time ";"
					mold type ";"
					mold module ";"
					mold uppercase/part msg 1
					newline
				]
			]
		]
	]
]

log-class: context [
	name: 'log-class
	
	log: func [msg /warn /error /info /fatal][
		case [
			warn  [logger/notify msg name 'warn]
			error [logger/notify msg name 'error]
			info  [logger/notify msg name 'info]
			fatal [logger/notify msg name 'fatal]
		]
	]
]