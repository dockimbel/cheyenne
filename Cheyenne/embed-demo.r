REBOL [
	Title: "Cheyenne Embedded Demo"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Version: 1.0
	Date: 09/06/2007
	Notes: {
		This is the first experimental release of Cheyenne's embed mode support.
		
		It relies on the new module : mod-embed.r
==>		(you should uncomment 'embed in httpd.cfg to activate it and be able to run this demo)
		
		All the other modules will be disabled while mod-embed is active (current behaviour, it may
		change in the future).
		
		The purpose is to be able to extend an existing application that wish to publish or expose
		some data or services externally using the HTTP protocol. This requires an internal web server
		and this is exactly what Cheyenne/mod-embed provides.
	
		In order to achieve that, I've simplified the API and the startup part, so, even if you never
		looked at Cheyenne RSP API, or Cheyenne module API, you should be able to quickly understand
		how this small new API works. This API is required to interface your code with Cheyenne and 
		the outer web world!
	
		Here's what you need to include in your REBOL app, to add an internal web server :
		
		1)	do/args %cheyenne.r "-e"
		
			This "magic" line loads and install the Cheyenne web server and all its dependencies.
			The -e command line option disables the automatic event loop, so it won't block and it
			will rely on you to launch the event loop (using, e.g., 'view or 'do-events).
			
		2)  publish-site [...specs...]
		
			This globally-defined function (installed by Cheyenne) allows you to describe a simple
			virtual web site and interface it with your own functions.
	
			The working principle of this interface is to provide a simple mapping of web URLs
			to REBOL objects and functions.
			
			Examples:
				/			=> 'default	function (catches 404 relative to /)
				/main 		=> 'main function
				/app/		=> 'app/default function (catches 404 relative to /app)
				/app/login	=> 'app/login function
				...
				and so on.
				
				The corresponding definition would be :
				
				publish-site [
					default: func [req params svc][...]
					main: 	 func [req params svc][...]
					app: 	 context [
						default: func [req params svc][...]
						login:   func [req params svc][...]
						...
					]
					...
				]
				
			So the 'specs block argument needed by 'publish-site is just a hierarchy of objects and
			functions processing the requests and building adequat responses.
			
			These functions prototype is always the same. Here's a short description of the arguments :
				
				o req: [object!] encapsulates the request and response. (see "1.2. Phase Implementation"
				  in %docs/developer-guide.html for a description of the request object)
				  
				o params: [block!] list of name/value pairs of decoded parameters passed
				  through GET or POST.
				  
				o svc: [object!] reference to Cheyenne's HTTPd context. 
				  svc/client references the client port! value (useful to extract IP, server's port-id,...)
				  
			These functions have to return a string! or binary! value that will be sent back as response to the
			request.
			
			A very basic site that just displays time in your browser, could be :
			
			    publish-site [
			    	default: func [req params svc][
			    		req/out/code: 200
						build-markup "<html><body><%now/time%></body></hml>"
			    	]
			    ]
			    
			The same one, using some REBOL dialecting (for, e.g., a REBOL-based client) :
			
			    publish-site [
					default: func [req params svc][
						req/out/code: 200
						mold/all reduce ['time now/time]
					]
				]
				
			To be able to send a correct reply, you have to:
			
			1) set the HTTP return code	   (mandatory)
			2) set the Content-type header (if the target client is a web browser)
			
			Setting the HTTP return code :
			
				req/out/code: ... (integer!, usually 200)
				
			Setting an HTTP header :
			
				h-store req/out/headers 'Content-Type "text/html"
				
				h-store req/out/headers 'Connection "close"  (by default, the HTTP connections are persistent)
			
		Optionally, there are two callbacks that you can implement in your site definition :
		
			on-request: 	called first on each request (should return a logic! value)
			on-response:	called last on each response
			
			If defined, they will be called for all requests. They act as input/output filters.
			If 'on-request returns TRUE, no other processing would be done (the object/function
			mapping won't be done) and 'on-request have, in this case, to provide a proper response.
			
		This API was designed, not only for publishing HTML content to web browser, but to provide
		a more generic HTTP tunneling service to whatever service you would like to expose.
		
		A good usage could be to build a web-services provider (SOAP or REST services).
		
		The following demo shows a simple "hello world" web site with a tiny login system.	
		Run this script, then go to http://localhost.
		
		I hope you'll enjoy this new module and demo, I'll be pleased to hear you feedback about
		that on the !Cheyenne AltMe channel.
		
		--
		DocKimbel
		
		PS: This module design, implementation and demo were done in one day, so be forgiving
		for all the missing features and bugs.
	}
]

do/args %cheyenne.r "-e"

htmlize: func [title [string!] body [block! string!]][
	reform [
		<html>
		<head><title> title </title></head>
		<body>
			body
		</body>
		</html>
	]
]

publish-site [
	on-request: func [req params svc][
		info/color: red
		show info
		wait 0.1	; make the box flash in red when a request is received.
		false		; true: send the response, false: let other functions respond.
	]
	
	on-response: func [req params svc][	
		;-- this callback is useful to mutualize the HTTP response settings.
		req/out/code: 200
		h-store req/out/headers 'Content-Type "text/html"
		
		info/color: none
		show info
	]
	
	;-- "/"
	default: func [req params svc][
		htmlize "Home" [
			<center>
			<h1> "Welcome to default page !" </h1>
			<a href="hello"> "Hello World!" </a><br><br>
			<a href="/testapp/"> "Test-App" </a>
			</center>
		] 
	]
	hello: func [req params svc][
		htmlize "Hello" [<h1> "Hello world!" </h1>] 
	]
	
	;-- "/testapp/"
	testapp: context [
		logged?: no			; local variables can be used, they are excluded from the URL mapping
							; (only object! and function! can be called from outsite)

		default: func [req params svc][
			home req params svc
		]
		ask-login: func [req params svc][
			htmlize "login" [
				"(test/guest)" <br><br>
				<form method="POST" action="auth">
				"login:" <input type="text" name="login"><br>
				"pass:" <input type="password" name="pass">
				<input type="submit" value="post"
				</form>
			] 
		]
		auth: func [req params svc][
			either all [
				"test" = trim select params 'login
				"guest" = trim select params 'pass
			][
				logged?: yes
				home req params svc
			][
				ask-login req params svc
			]
		]
		logout: func [req params svc][
			logged?: no
			ask-login req params svc
		]
		home: func [req params svc][
			if not logged? [return ask-login req params svc]
			htmlize "Home" [
				<h1>"Welcome to Embedded Cheyenne!"</h1>
				<a href="logout">"Logout"</a>
			]	
		]
	]
]

view layout [
	info: box "This is a View script with an embedded Cheyenne web server" font [
		shadow: none
		color: black
		size: 12
	]
]