REBOL [
	Purpose: "test RSP handling of plain REBOL scripts"
]

emit [
	<HTML>
	<HEAD>
		<TITLE> "RSP Test Page" </TITLE>
	</HEAD>
	<BODY bgcolor="white">
	<a href="/">Back</a><br><br>
	<FONT FACE="Arial" SIZE='-1'>
	<B>"Timestamp: "</B> now
	<BR><BR>
	<H4>"Request parameters :"</H4>
	<UL>
		<LI><B>"HTTP Method: "</B> 			mold request/method 	 </LI>
		<LI><B>"HTTP Port: "</B> 			mold request/server-port </LI>
		<LI><B>"Client IP address: "</B> 	mold request/client-ip 	 </LI>
	</UL>
	<H4>"Request headers :"</H4>
	<UL>
]
foreach [name value] request/headers [
	emit [<LI><B> name ":"</B> html-encode mold value </LI>]
]
emit [
	</UL>
	<H4>"Request variables :"</H4>
	<UL>
]
either empty? request/content [
	emit "<LI>No variable passed</LI>"
][
	foreach [name value] request/content [
		emit [<LI><B> name ":"</B> html-encode mold value </LI>]
	]
]
emit [
	</UL>
	<H4>"Session :"</H4>
]
either session/content [
	emit [
	 <UL>
		<LI><B>"SID: "</B> session/id </LI>
	]
	either empty? session/content [
		emit "<LI>No session variables</LI>"
	][
		foreach [name value] session/content [
			emit [<LI><B> name ":"</B> html-encode mold value </LI>]
		]
	]
	emit </UL>
][
	
	emit [<UL><LI>"No session"</LI></UL>]
]
emit [
	</FONT>
	</BODY>
	</HTML>
]
debug/print "show.r script evaluated without errors"