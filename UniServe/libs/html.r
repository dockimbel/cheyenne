REBOL [
	Title: "URL and HTML codecs library"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Version: 2.0.1
	Date: 15/08/2009
]

set 'convert func [
	"Rule-based string series conversion. Returns a new series."
	series [any-string!] "input string (unmodified)"
	rule [block!] "matching patterns described by a PARSE rule"
	body [block!] {
		Body evaluated on matched pattern. 
		VALUE word refers to the matched pattern.
		OUT word refers to the new series.
		You have to return the new converted value.
		
		Do not use '__s and '__e words in the body.
	}
	/local out value __s __e 
][
	out: make string! length? series
	bind body 'out
	parse/all series [
		__s: any [
			__e: copy value rule (
				insert/part tail out __s __e
				insert tail out do body
			) __s: | skip
		] __e:
		(insert/part tail out __s __e)
	]
	out
]

context [
	alphanum: charset [#"0" - #"9" #"a" - #"z" #"A" - #"Z"]
	entbase:  charset ["^"&" #"^(A0)" - #"^(FF)"]
	entchar:  union entbase charset "<>"
	url-special:  charset "$-_.+!*'(),"
	url-reserved: charset "&/:;=?@"
	url-not-allowed: reduce [
		complement union alphanum url-special
		complement union alphanum union url-special url-reserved
	]

	; -- ASCII and ISO-8859-1 entities
	entities: make hash! [
		"&quot;"	#"^(22)"	"&frac34;"	#"^(BE)"	"&agrave;"	#"^(E0)"
		"&amp;"		#"^(26)"	"&iquest;"	#"^(BF)"	"&aacute;"	#"^(E1)"
		"&lt;"		#"^(3C)"	"&Agrave;"	#"^(C0)"	"&acirc;"	#"^(E2)"
		"&gt;"		#"^(3E)"	"&Aacute;"	#"^(C1)"	"&atilde;"	#"^(E3)"
		"&nbsp;"	#"^(A0)"	"&Acirc;"	#"^(C2)"	"&auml;"	#"^(E4)"
		"&iexcl;"	#"^(A1)"	"&Atilde;"	#"^(C3)"	"&aring;"	#"^(E5)"
		"&cent;"	#"^(A2)"	"&Auml;"	#"^(C4)"	"&aelig;"	#"^(E6)"
		"&pound;"	#"^(A3)"	"&Aring;"	#"^(C5)"	"&ccedil;"	#"^(E7)"
		"&curren;"	#"^(A4)"	"&AElig;"	#"^(C6)"	"&egrave;"	#"^(E8)"
		"&yen;"		#"^(A5)"	"&Ccedil;"	#"^(C7)"	"&eacute;"	#"^(E9)"
		"&brvbar;"	#"^(A6)"	"&Egrave;"	#"^(C8)"	"&ecirc;"	#"^(EA)"
		"&sect;"	#"^(A7)"	"&Eacute;"	#"^(C9)"	"&euml;"	#"^(EB)"
		"&uml;"		#"^(A8)"	"&Ecirc;"	#"^(CA)"	"&igrave;"	#"^(EC)"
		"&copy;"	#"^(A9)"	"&Euml;"	#"^(CB)"	"&iacute;"	#"^(ED)"
		"&ordf;"	#"^(AA)"	"&Igrave;"	#"^(CC)"	"&icirc;"	#"^(EE)"
		"&laquo;"	#"^(AB)"	"&Iacute;"	#"^(CD)"	"&iuml;"	#"^(EF)"
		"&not;"		#"^(AC)"	"&Icirc;"	#"^(CE)"	"&eth;"		#"^(F0)"
		"&shy;"		#"^(AD)"	"&Iuml;"	#"^(CF)"	"&ntilde;"	#"^(F1)"
		"&reg;"		#"^(AE)"	"&ETH;"		#"^(D0)"	"&ograve;"	#"^(F2)"
		"&macr;"	#"^(AF)"	"&Ntilde;"	#"^(D1)"	"&oacute;"	#"^(F3)"
		"&deg;"		#"^(B0)"	"&Ograve;"	#"^(D2)"	"&ocirc;"	#"^(F4)"
		"&plusmn;"	#"^(B1)"	"&Oacute;"	#"^(D3)"	"&otilde;"	#"^(F5)"
		"&sup2;"	#"^(B2)"	"&Ocirc;"	#"^(D4)"	"&ouml;"	#"^(F6)"
		"&sup3;"	#"^(B3)"	"&Otilde;"	#"^(D5)"	"&divide;"	#"^(F7)"
		"&acute;"	#"^(B4)"	"&Ouml;"	#"^(D6)"	"&oslash;"	#"^(F8)"
		"&micro;"	#"^(B5)"	"&times;"	#"^(D7)"	"&ugrave;"	#"^(F9)"
		"&para;"	#"^(B6)"	"&Oslash;"	#"^(D8)"	"&uacute;"	#"^(FA)"
		"&middot;"	#"^(B7)"	"&Ugrave;"	#"^(D9)"	"&ucirc;"	#"^(FB)"
		"&cedil;"	#"^(B8)"	"&Uacute;"	#"^(DA)"	"&uuml;"	#"^(FC)"
		"&sup1;"	#"^(B9)"	"&Ucirc;"	#"^(DB)"	"&yacute;"	#"^(FD)"
		"&ordm;"	#"^(BA)"	"&Uuml;"	#"^(DC)"	"&thorn;"	#"^(FE)"
		"&raquo;"	#"^(BB)"	"&Yacute;"	#"^(DD)"	"&yuml;"	#"^(FF)"
		"&frac14;"	#"^(BC)"	"&THORN;"	#"^(DE)"	
		"&frac12;"	#"^(BD)"	"&szlig;"	#"^(DF)"	
														
	]

	set 'html-decode func [data [string! binary!]][
		convert data [#"&" 2 6 alphanum #";"][
			any [select entities value value]
		]
	]
	
	set 'html-encode func [data [string! binary!] /no-tags][
		convert data [entchar][
			pick find entities to char! value -1
		]
	]
	
	set 'entities-encode func [data [string! binary!] /no-tags][
		convert data [entbase][
			pick find entities to char! value -1
		]
	]
	
	set 'url-encode func [data [string! url!] /all /local chars][
		chars: pick url-not-allowed to logic! all
		convert data [chars][
			reduce [#"%" skip to-hex to integer! to char! value 6]
		]
	]
]
