REBOL [
	Title: "Web Socket test application"
	Author: "Nenad Rakocevic/Softinnov"
	Date: 29/12/2009
]

;-- Web socket applications are loaded in Cheyenne/UniServe main process.
;-- To make a new web socket app, just use the 'install-socket-app handler and
;-- provide a spec block giving at least an application name and implementing one
;-- or several of available handlers. As this is running in main process, when
;-- any handler runs, it will block the server, so, you have to keep your code
;-- very efficient, it should run in between 1ms and 10ms if you want your Cheyenne
;-- server be able to scale to hundreds of concurrent clients. That's the cost to
;-- pay for not having multi-threading...Anyway, you can use the 'do-task function
;-- to run longer code without blocking. The request will be passed to the initial RSP
;-- script used to established the socket connection.
;--
;-- In addition, the mapping between the URL and the socket application MUST be defined in
;-- %httpd.cfg config file in host or webapp sections using 'socket-app keyword :
;--
;-- 	ex:  socket-app "/ws.rsp" ws-test-app
;--

install-socket-app [								;-- load application at Cheyenne startup
	name: 'ws-test-app								;-- mandatory name, filename have to be identical
	
	;-- on-connect event happens when a new web socket is open by a remote client.
	;-- the 'client argument is the port! value used to comunicate with the client
	;-- it also uniquely identifies the connection. Client port will be automatically
	;-- added to connection list called 'clients that can be read at any time (read only!).
	on-connect: func [client][						
		print "client socket connected!"
		if not timer? [								;-- 'timer? returns TRUE is a timer is running else FALSE (read only!)
			set-timer 0:0:05						;-- switch on timer event for this app with a delay of
		]											;-- 5 secs between each one.
	]
	
	;-- on-disconnect event happens when a client disconnects or when you use the 'disconnect
	;-- function to force disconnection. The 'client argument is the client port value. Once
	;-- this event processed, the client port is removed from the 'clients list of connections.
	on-disconnect: func [client][
		print "client socket disconnected!"
		if empty? clients [							;-- 'clients connection list is a hash!, so all series functions apply.
			set-timer none							;-- passing none to 'set-timer will stop the timer.
		]
	]
	
	;-- on-message event happens when the server receives a message from the client (can happen only
	;-- while the connection is opened). The client port is passed in 'client argument. The 'data argument
	;--	contains the text message as a string! value from the client in UTF-8 encoding.
	on-message: func [client data][						
		;send data									;-- 'send function emit string! data to client (must be UTF-8 encoded!).
													;-- 'send will emit the data to the client from which the message originates.
		do-task/on-done data func [client data][	;-- 'do-task processes the argument data (can be anything) in background 
			data: uppercase data					;--	simulates a post-processing action
			print ["post-processing:" data]
			send/with data client
		]
	]												;-- passing the data to the initial RSP script. Currently, the response
													;-- data from the RSP is sent directly to the client.

	;-- on-timer event happens only if 'set-timer has been used previously with a time! value.
	;-- This event will keep been generated until 'set-timer is called with 'none value.
	on-timer: does [
		foreach port clients [						;-- 'clients series can be traversed
			send/with "tick" port					;-- 'send is used here with /with refinement, in order to point
		]											;-- to the right client port. In 'on-timer, there's no implicit
	]												;-- client port.
	
	;-- RSP session support (should work ok, but untested yet)
	;-- If the socket has been opened from a RSP webapp, the session object is available from within the
	;-- socket application. Usage:
	;--
	;--		rsp-session/vars	;-- block of name/value pairs (word! anytype!). Reading is always safe.
	;--							;-- Writing *only* if no background tasks is running.
	;--
	;--		rsp-session/busy?		;-- returns TRUE is a background task is running else FALSE. Use it
	;--							;--	to synchronize session variables writings.
]

;-- Implementation pending for :
;--   v  - 'on-message should have a 'client argument in addition to the 'data value.
;--   v  - 'on-done event for 'do-task return action to be able to post-process it before sending data to client
;--   v  - 'session object to access session data shared by RSP processes.
;--   v  - protected /ws-apps folder from direct access.
;--   v	 - reloading socket apps if modified
;--   v  - 'do-task support in 'on-timer 