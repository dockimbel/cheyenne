REBOL []

context [
	digit: charset "0123456789"
	blank: #" "
	
	days: ["Mon," "Tue," "Wed," "Thu," "Fri," "Sat," "Sun,"]
	months: ["Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"]
	
	set 'prefix0 func [time [time!]][
		time: either time/hour < 10 [head insert mold time #"0"][mold time]
		if 5 = length? time [append time ":00"]
		time
	]
	
	set 'to-UTC func [date [date!]][date - date/zone]
	
	set 'to-GMT-idate func [date [date!] /UTC /local cache str new][
		cache: #[hash! []]
		if UTC [date: to-UTC date]
		either str: select cache date [str][	
			insert tail cache date
			insert tail cache new: form reduce [
				pick days date/weekday
				join any [all [date/day < 10 #"0"] ""] date/day
				pick months date/month
				date/year 
				prefix0 any [date/time 0:0]
				"GMT"
			]
			if 200 < length? cache [clear cache]	;-- 100 dates cached max
			new
		]
	]
	
	set 'to-CLF-idate func [date [date!] /local cache tmp dt][
		cache: #[hash! [0:00:01 ""]]
		either date = first cache [second cache][	
			cache/1: date
			dt: clear cache/2
			insert tail dt #"["
			if date/day < 10 [insert tail dt #"0"]
			insert tail dt date/day
			insert tail dt slash
			insert tail dt pick months date/month
			insert tail dt slash
			insert tail dt date/year
			insert tail dt #":"
			tmp: date/time
			if tmp/hour < 10 [insert tail dt #"0"]
			insert tail dt tmp
			if zero? tmp/second [insert tail dt ":00"]
			insert tail dt #" "
			insert tail dt any [all [negative? date/zone #"-"] #"+"]
			if lesser? tmp: date/zone/hour 10 [insert tail dt #"0"]
			insert tail dt tmp
			if lesser? tmp: date/zone/minute 10 [insert tail dt #"0"]
			insert tail dt tmp
			insert tail dt #"]"
			dt
		]
	]

	set 'to-rebol-date func [data [string!] /local asc pos][
		parse/all data [thru blank data: [digit (asc: yes) | (asc: no)]]
		if pos: find data #";" [clear pos]
		if not asc [		
			data: parse data none		
			insert data second data
			change at data 3 fifth data
			remove back tail data
			data: form data			
		]
		attempt [to date! data]
	]
]