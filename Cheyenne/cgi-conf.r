REBOL [
  Title: "Configure CGI demos for the OS"
  Author: onetom@hackerspace.sg
  Date: 2011-04-18
  Description: {
    There are some CGI examples configured with Windows paths for the
    Perl and Rebol interpreters:

      #!C:\Perl\bin\perl.exe -wT
      #!c:\dev\sdk\tools\rebol.exe --cgi

    Under UNIX systems these should be replaced with that version which can be
    found in the $PATH. The scripts should be given an executable flag too.
  }
]

foreach [file interpreter options] [
	%www/perl/env.cgi perl "-wT"
	%www/perl/post.cgi perl "-wT"
	%www/show.cgi rebol "--cgi"
] [
  call/output reform ['which interpreter] path: copy ""
  either empty? trim/lines path [
	print [interpreter "not found"]
  ][
	probe hash-bang: rejoin ["#!" path " " options]
	write/lines file head change/part (read/lines file) hash-bang 1
	call reform ["chmod +x" file]
  ]
]
