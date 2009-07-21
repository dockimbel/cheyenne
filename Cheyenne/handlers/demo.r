REBOL [
	Title: "DEMO handler"
]

install-module [
	name: 'demo
	
	on-task-received: func [data][	
		data: reduce load data
	
		result: reform [		; you have to return the response string in 'result
			<html><body>
				"Your IP is :" data/ip
			</html></body>
		]
	]
]