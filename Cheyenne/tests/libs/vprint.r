rebol [
    title:      {vprint: tracing/logging management tool}
	file:       %vprint.r
	version: 	1.3.2
	date: 		2008-12-11
	author:		"Maxim Olivier-Adlhoch"
	copyright:	"Copyright (c) 2002-2008 Maxim Olivier-Adlhoch"
	license:    'mit
	purpose:	"programatically selectable, indented printing/tracing/logging/debugging engine."
    
	changes: {}
	History: {
		v1.2.2 - 8-May-2006/12:44:49 (MOA)
			-unified tag usage by adding print?() and indented-print()
			-updated v??()
			-added vprint() and related indented-prin()
	
		v1.2.3 - 2-Jun-2006/11:36:28 (MOA)
			-add log-file capapabilites to whole module
			-reworked some funcs to accomodate the logging.
			-fixed a few logging-related bugs.
	
		v1.2.4 - 6-Jun-2006/16:39:48 (MOA)
			-added vlogclear
			-von always sets verbose on, otherwise tags don't work anyways.
	
		v1.3.0 - 10-Jun-2006/18:17:36 (MOA)
	
		v1.3.1 - 2008-12-11/15:22:40 (max)
			-optimised exclude
			-one or two little tweaks (fixes?)

		v1.3.2 - 2008-12-11/15:29:29 (max)
			-license change to MIT
	}
	todo: {
		-include vask function in public distribution, which functions the same way as the other vprint
		 functions but instead causes a break in the code, by asking a question in the console.
		 
		 This function also responds to tags, so you can switch any breakpoints, programatically!
		 
		-create a view-enabled version of vask, which pops up a modal window, forcing you to click "ok" 
		 before app continues.
		 
	}
]



;; conditional lib execution, simulates C/C++ #ifndef 
do unless (value? 'lib-vprint) [[


;; declare lib
lib-vprint: true


lib-vprint-ctx: context [
;-------------------------------
;  VERBOSE PRINTING MANAGEMENT
;-------------------------------

;-------------------------------
; vprint mechanism is copyright (c) 2002-2006 Maxim Olivier-Adlhoch
; licensed commercially for the Railnet 2 project
;-------------------------------


;-------------------------------
;- VALUES
;-------------------------------
verbose:    false   ; display console messages
vtabs: []
ltabs: []

vtags: copy []			; setting this to a block of tags to print, allows vtags to function, making console messages very selective.
ntags: copy []			; setting this to a block of tags to ignore, prevents vtags to function, making console messages very selective.
log-vtags: copy []     ; selective logging selection
log-ntags: copy []     ; selective logging ignoring.
vconsole: none		; setting this to a block, means all console messages go here instead of in the console and can be spied on later !"

vlogfile: none

;-------------------------------
;- FUNCTIONS
;-------------------------------

;----------------
;-    MATCH-TAGS()
;----
match-tags: func [
	"return true if the specified tags match an expected template"
	template [block!]
	tags [block! none!]
	/local tag success
][
	success = False
	if tags [
		foreach tag template [
			if any [
				all [
					; match all the tags at once
					block? tag
					((intersect tag tags) = tag)
				]
				
				all [
					;word? tag
					found? find tags tag
				]
			][
				success: True
				break
			]
		]
	]
	success
]




;----------------
;-    PRINT?()
;----
print?: func [
	error
	always
	tags
][
	all [
		any [
			error
			all [
				any [verbose always] 
				not any [
					all [
						not empty? vtags
						not match-tags vtags tags
					]
					all [
						not empty? ntags
						match-tags ntags tags
					]
				]
			]
		]
	]	
]

;----------------
;-    LOG?()
;----
log?: func [
	error
	always
	tags
][
	either file? vlogfile [
		any [
			error
			all [
				any [verbose always] 
			]
		]
	][
		none
	]
]





;----------------
;-    INDENTED-PRINT()
;----
indented-print: func [
	data
	in
	out
	/log
	/local line do tabs
][
	tabs: either log [ltabs][vtabs]
	line: copy ""
	if out [remove tabs]
	append line tabs
	switch/default (type?/word data) [
		object! [append line mold first data]
		block! [append line rejoin data]
		string! [append line data]
		none! []
	][append line mold reduce data]
	
	if in [insert tabs "^-"]
	
	line: replace/all line "^/" join "^/" tabs
	
	
	either log [
		write/append vlogfile join line "^/" ; we must add the trailing new-line
	][
		either vconsole [
			append/only vconsole line
		][
			print line
		]
	]
	
]



;----------------
;-    INDENTED-PRIN()
;----
indented-prin: func [
	data
	/log
	/local line do tabs
][
	tabs: either log [ltabs][vtabs]
	line: copy ""
	switch/default (type?/word data) [
		object! [append line mold first data]
		block! [append line rejoin data]
		string! [append line data]
		none! []
	][append line mold reduce data]
	
	line: replace/all line "^/" join "^/" tabs 
	
	either log [
		write/append vlogfile line
	][
		either vconsole [
			append/only vconsole line 
		][
			prin line
		]
	]


]






;----------------
;-    VOFF()
;----
set 'voff func [/tags dark-tags  /log log-tags] [
	either any [tags log][
		if tags [
			
			vtags-ctrl dark-tags ntags vtags
		]
		if log [
			
			vtags-ctrl log-tags log-ntags log-vtags
		]
	][
		verbose: off
		if block? log-vtags [clear log-vtags]
		if block? vtags [clear vtags]
	]
]




;----------------
;-    VON()
;----
set 'von func [/tags lit-tags  /log log-tags] [
	verbose: on
	either any [ tags log ][
		if tags [
			vtags-ctrl lit-tags vtags ntags
		]
		if log [
			vtags-ctrl log-tags log-vtags log-ntags
		]
	][
		if block? log-ntags [clear log-ntags]
		if block? ntags [clear ntags]
	]
]



;----------------
;-    EXCLUDE()
;----
exlude: func [serieA serieB][
	remove-each item serieB [
		find serieA item 
	]
]



;----------------
;-    INCLUDE()
;----
include: func [serieA serieB][
	foreach item serieB [
		unless find serieA item [
			append/only serieA item
		]
	]
]



;----------------
;-    VTAGS-CTRL()
;----
vtags-ctrl: func [
	set
	tags
	antitags
][
	unless block? set [
		set: reduce [set]
	]
	if block? antitags [
		exclude antitags set
	]
	
	include tags set
]	



;----------------
;-    VIN()
;----
set 'vin func [
	txt
	/error
	/always
	/tags ftags [block!]
][
	if print? error always ftags [
		;vprint/in/always/tags join txt " [" ftags
		indented-print join txt " [" yes no
	]
	
	if log? error always ftags [
		indented-print/log join txt " [" yes no
	]
]




;----------------
;-    VOUT()
;----
set 'vout func [
	/error
	/always
	/tags ftags
	/return rdata ; use the supplied data as our return data, allows vout to be placed at end of a 
	              ; function and print itself outside inner content event if return value is a function.
][

	if print? error always ftags [
		indented-print "]" no yes
	]
	
	if log? error always ftags [
		indented-print/log "]" no yes
	]
	
	; this mimics print's functionality where not supplying return value will return unset!, causing an error in a func which expects a return value.
	either return [
		rdata
	][]
]





;----------------
;-    VPRINT()
;----
set 'vprint func [
	"verbose print"
	data
	/in "indents after printing"
	/out "un indents before printing. Use none so that nothing is printed"
	/error "like always, but adds stack trace"
	/always "always print, even if verbose is off"
	/tags ftags "only effective if one of the specified tags exist in vtags"
][
	if print? error always ftags [
		indented-print data in out
	]
	if log? error always ftags [
		indented-print/log data in out
	]
]



;----------------
;-    VPRIN()
;----
set 'vprin func [
	"verbose print"
	data
	/error "like always, but adds stack trace"
	/always "always print, even if verbose is off"
	/tags ftags "only effective if one of the specified tags exist in vtags"
][
	if print? error always ftags [
		indented-prin data
	]
	if log? error always ftags [
		indented-prin/log data
	]
]





;----------------
;-    VPROBE()
;----
set 'vprobe func [
	"verbose probe"
	data
	/in "indents after probing"
	/out "un indents before probing"
	/error "like always, but adds stack trace"
	/always "always print, even if verbose is off"
	/tags ftags "only effective if one of the specified tags exist in vtags"
	/part amount [integer!] "how much object do we want to display, should eventually support block of words"
	/local line
][
	unless part [
		amount: 500
	]
	
	switch/default (type?/word :data) [
		object! [
			line: rejoin [ mold first data "^/>>>" copy/part mold/all data amount "<<<"]
		] 
	][
		line: mold/all :data ; serialised values are explicit (better probe precision).
	]
	
	if print? error always ftags [
		indented-print line in out  ; part of indented-print
	]
			
	if log? error always ftags [
		indented-print/log line in out  ; part of indented-print
	]
			
	:data
]





;----------------
;-    V??()
;----
set 'v?? func [
    {Prints a variable name followed by its molded value. (for debugging) - (replaces REBOL mezzanine)}
    'name
	/error "like always, but adds stack trace"
	/always "always print, even if verbose is off"
	/tags ftags "only effective if one of the specified tags exist in vtags"
	/local value
][
	value: either word? :name [
		head insert tail form name reduce [": " mold name: get name]
	][
		mold :name
	]
		
	if print? error always ftags [
		indented-print value false false  ; in out
	]
	if log? error always ftags [
		indented-print/log value false false  ; in out
	]
		
	:name
]



;----------------
;-    VLOGCLEAR()
;----
set 'vlogclear func [][
	if all [file? vlogfile exists? vlogfile][
		; more effective than a delete, cause if the file is being traced or read by another tool,
		; a lock will be effective on the file.  In this case, files cannot be deleted or renamed.
		; but changing its content is still possible. So by clearing it we effectively remove the disk space and
		; reset it even if a file opened lock exists.
		write vlogfile ""
	]
]






;----------------
;-    VFLUSH()
;----
set 'vflush func [/disk logfile [file!]] [
	if block? vconsole [
		forall head vconsole [
			append first vconsole "^/"
		]
		either disk [
			write logfile rejoin head vconsole
		][
			print head vconsole
		]
		clear head vconsole
	]
]

; end lib
;print "loaded vprint library"


]]]