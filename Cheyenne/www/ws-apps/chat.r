REBOL [
	Title: "Web Socket realtime chat demo"
	Author: "Nenad Rakocevic/Softinnov"
	Date: 01/10/2010
]

install-socket-app [
	name: 'chat
	
	users: make block! 10									;-- stores [port! string!] pairs
	history: make block! 50
	
	broadcast: func [msg][
		foreach port clients [send port msg]				;-- send same data to all connected users
	]
	
	on-connect: func [client][
		foreach entry history [send client entry]			;-- send msgs' history to new user
		foreach [port user] users [send client user]		;-- send connected users list
	]
	
	on-message: func [client data][
		;-- escape all html tags for security concerns
		data: copy data
		replace/all data "<" "&lt;"
		replace/all data ">" "&gt;"
		
		switch data/1 [
			#"m" [
				insert next data join remold [now/time] " " ;-- insert [hh:mm:ss] time prefix
				append history data
				if 50 <= length? history [remove history]	;-- keep only 50 msgs in history
			]
			#"u" [
				if not find users data [
					repend users [client data]				;-- keep users list updated
				]
			]
		]
		broadcast data										;-- broadcast messages to all users
	]
	
	on-disconnect: func [client /local pos user][
		pos: find users client
		user: pos/2
		remove/part pos 2
		broadcast head change user #"r"						;-- send user quit msg to everyone
	]
]