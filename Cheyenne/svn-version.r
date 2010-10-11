REBOL [
	Title: "SVN Version"
	Date: 11-Oct-2010
	Version: 1.0.1
	File: %svn-version.r
	Author: "Nenad Rakocevic"
	Usage: {
		>> svn-version? %/c/dev/cheyenne-server/
		== 92
	}
    Purpose: {
    	Retrieve the global revision number from a local SVN repository.
    	This mimics the feature offered by the svnversion command-line tool
    	See: http://svnbook.red-bean.com/en/1.1/re57.html
    	
    	This can be used in PREBOL (or other scripts preprocessors) to insert the
    	SVN global revision number as a build version.
    }
    Email: nr@softinnov.com
	Library: [
		level: 'intermediate
		platform: 'all
		type: [tool tutorial]
		domain: [file-handling parse]
		tested-under: "Core 2.7.6 Windows 7"
		support: none
		license: 'BSD
		see-also: none
	]
]

context [
	revision: svn-dir: none
	digit: charset "0123456789"
	
	dir?: func [file [file!]][slash = last file]
	
	process: func [file /local value][
		parse/all read file [
			any [
				"!svn/ver/" copy value some digit (				
					if revision < value: to integer! value [revision: value]
				) | skip
			]
		]
	]
	
	dive: func [path /local file][
		if exists? file: path/:svn-dir/all-wcprops [process file]
		foreach file read path [
			if all [
				dir? file
				file <> svn-dir/all-wcprops
			][
				dive path/:file
			]
		]
	]

	set 'svn-version? func [
		"Return the global SVN revision number from a local SVN repository"
		path [file!]	"SVN repository folder"
		/alt-dir		"Search in _svn/ instead of .svn/ folders"
	][
		revision: 0
		svn-dir: pick [%_svn/ %.svn/] to-logic alt-dir
		if not dir? path [append path slash]
		dive path
		revision
	]
]