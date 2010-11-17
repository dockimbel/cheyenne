#!c:\dev\sdk\tools\rebol.exe  --cgi

REBOL [
    Title:      "show"
    File:       %show.cgi
]

print "Content-type: text/html^/"
print {<HTML><BODY><FONT FACE='ARIAL' SIZE='-1'><a href="/">Back</a><br><br>}
print ["<B>Script path :</B>" system/script/path "<BR><BR>"]
print "<B>CGI Object :</B>"
print "<UL>"

foreach name next first system/options/cgi [
	either :name = 'other-headers [
		print ["<LI><B>   " name ": </B><UL>"]
		foreach [n v] list: system/options/cgi/:name [
			print ["<LI><FONT FACE='ARIAL' SIZE='-1'>   " n ": </B>" mold select list n "</FONT></LI>"]
		]
		print "</UL></LI>"
	][
		print ["<LI><B>   " name ": </B>" mold system/options/cgi/:name "</LI>"]
	]
]
print "</UL>"

if system/options/cgi/request-method = "POST" [
	vars: make object! decode-cgi as-string input
	if not empty? next first vars [
		print "<FONT FACE='ARIAL' SIZE='-1'><B> Variables passed :</B><BR><UL>"
		foreach name next first vars [
			print ["<LI><FONT FACE='ARIAL' SIZE='-1'>   " name ": </B>" mold vars/:name "</FONT></LI>"]
		]
		print "</FONT></UL>"
	]
]
print "</FONT></BODY></HTML>"
