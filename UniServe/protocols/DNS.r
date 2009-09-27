REBOL [
	Title: "DNS Async wrapper"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Version: 1.1.0
	Date: 20/09/2009
]

install-protocol [
	name: 'DNS
	scheme: 'dns
	
	on-received: func [data][
		on-resolved server data
	]
	
	events: [
		on-resolved		; [port [port!] ip [tuple! none!]]
		on-error		; [port code]
	]
]