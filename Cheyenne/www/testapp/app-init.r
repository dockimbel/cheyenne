REBOL [
	Purpose: "RSP environement init code"
]

on-application-start: does [
	;--- add here your library / modules loading
]

on-application-end: does [
	;--- add here your library / modules proper closing
]

on-session-start: does [
	;--- add here your per session init code
	;--- ex: session/add 'foo 0
	;--- that can be latter accessed with : session/content/foo
	
	session/add 'user "guest"
	session/add 'hits 1
]

on-session-end: does [
	;--- add here your per session closing/cleanup code

]

on-page-start: has [][
	set 't0 now/time/precise
]

on-page-end: has [pos time][
	if pos: find response/buffer "</body>" [
		time: to-integer 1000 * to-decimal (now/time/precise - t0)
		insert pos reform [
			"<br><br><small>Processed in :"
			either zero? time ["< 1"][time]
			"ms.</small>"
		]
	]
]