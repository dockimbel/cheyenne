;=== Copy this file and set your own encap paths

;--- Windows include paths ---
#if [system/version/4 = 3] [
	#include %//dev/REBOL/SDK/Source/mezz.r
	#include %//dev/REBOL/SDK/Source/prot.r
	#include %//dev/REBOL/SDK/Source/gfx-colors.r
]
;--- OS X include paths ---
#if [system/version/4 = 2] [
	#include %/Users/dk/dev/sdk/source/mezz.r
	#include %/Users/dk/dev/sdk/source/prot.r
	#include %/Users/dk/dev/sdk/source/gfx-colors.r
]
;--- Linux include paths ---
#if [system/version/4 = 4] [
	#include %/root/Desktop/sdk/source/mezz.r
	#include %/root/Desktop/sdk/source/prot.r
	#include %/root/Desktop/sdk/source/gfx-colors.r
]
