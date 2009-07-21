REBOL [
	Title: "Windows 95 skins"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Copyright: "@ 2001-2004 SOFTINNOV"
	Email: nr@softinnov.com
	Date: 03/10/2004
	Version: 0.9.0
	License: "BSD License, read the complete text in %docs/license.txt"
]

drop-list-event: func [face event /local svd area][
	if all [
		svd: winskin/drop-list
		find [down alt-down] event/type
		not within? event/offset svd/offset svd/size
	][	
		remove find event/face/pane svd
		area: any [all [svd/parent/no-edit svd/parent] svd/arrow]
		if not within? event/offset win-offset? area area/size [
			svd/active?: no
		]
		winskin/drop-list: none
		show event/face
	]
	event
]

if not find system/view/screen-face/feel/event-funcs :drop-list-event [
	insert-event-func :drop-list-event
]

winskin: context [
	drop-list: none
	font: either system/version/4 = 3 ["MS Sans Serif"][:font-sans-serif]
	font-size: 12
	
	sz: none

	colors: reduce [
		'font 	black
		'back 	188.188.188
		'field 	white
		'high	0.0.128
	]

	if value? 'get-reg [
		colors/back: to-tuple load get-reg/HKCU "Control Panel\Colors" "ActiveBorder"
	]

	edges: [
		pushed	[draw [pen black box 0x0 (sz - 1x1) pen 128.128.128 box 1x1 (sz - 2x2)]]
		bevel	[draw [
			pen white line (sz/y - 1 * 0x1) 0x0 (sz/x - 1 * 1x0)
			pen black line (sz/y - 1 * 0x1) (sz - 1x1) (sz/x - 1 * 1x0)
			pen 223.223.223 line (sz/y - 2 * 0x1 + 1x0) 1x1 (sz/x - 2 * 1x0 + 0x1)
			pen 128.128.128 line (sz/y - 2 * 0x1 + 1x0) (sz - 2x2) (sz/x - 2 * 1x0 + 0x1)
		]]
		tab-bevel [draw [
			pen white line (sz/y - 1 * 0x1) 0x0 (sz/x - 1 * 1x0)
			pen black line (sz - 1x1) (sz/x - 1 * 1x0)
			pen 223.223.223 line (sz/y - 2 * 0x1 + 1x0) 1x1 (sz/x - 2 * 1x0 + 0x1)
			pen 128.128.128 line (sz - 2x1) (sz/x - 2 * 1x0 + 0x1)
		]]
	]

	ibevel-effect: func [face /local edg][
		sz: face/size
		edg: compose/deep edges/bevel
		poke edg/2 2 128.128.128
		poke edg/2 8 white
		poke edg/2 14 black
		poke edg/2 20 223.223.223
		edg
	]

	get-effect: func [size name][
		sz: size
		compose/deep edges/:name
	]

	but-effects: func [face][
		sz: face/size
		compose/deep reduce [edges/pushed edges/bevel]
	]

	but-set-image: func [face /local sz res img z][
		if not face/text [
			if system/version <= 1.2.8.3.1 [
				 face/text: "."
				 face/font/color: face/color
				 if face/font/colors [face/font/colors/1: face/color]
			]
		]
		sz: face/size - (2 * face/edge/size)
		if img: any [face/image face/last-img][
			z: sz - (face/para/margin * 2) - (size-text face)
			res: compose/deep [[draw [image (img) (
				z/x: switch/default face/font/align [
					left	[(z/x - img/size/x) / 2 + sz/x - z/x]
					right	[(z/x - img/size/x) / 2]
				][(sz/x - img/size/x) / 2]
				z/y: switch/default face/font/valign [
					top		[(z/y - img/size/y) / 2 + sz/y - z/y]
					bottom	[(z/y - img/size/y) / 2]
				][(sz/y - img/size/y) / 2]
				z
			)]][draw [image (img) (z + 1x1)]]]
			if face/image [face/last-img: face/image face/image: none]
			either face/effects [
				insert face/effects/1 res/1
				insert face/effects/2 res/2
			][
				face/effects: res
			]
		]
	]

	scroller-feel: [
		engage: func [f action event][
			switch action [
				down [
					f/para/scroll: 1x1 f/state: on
					set-col f 1 do-face f f/parent-face/step f/rate: 4
				]
				alt-down [f/state: on ]
				up [
					if f/state [f/para/scroll: 0x0]
					f/state: flag: no f/rate: none set-col f 2
				]
				time [
					either flag [
						either f/rate <> f/parent-face/speed [
							f/rate: f/parent-face/speed
						][
							do-face f f/parent-face/step
						]
					][flag: on exit]
				]
				alt-up [if f/state [do-face-alt f none] f/state: off]
				over [
					if not f/state [f/para/scroll: 1x1] f/state: on
					set-col f 1 if flag [f/rate: f/parent-face/speed]
				]
				away [
					if f/state [f/para/scroll: 0x0] f/state: off
					f/rate: none set-col f 2
				]
			]
			cue f action
			show f
		]
		set-col: get in svvf/scroll-button 'set-col
		flag: false
	]
	
	table-row-feel: make face/feel [
		cell: none
		redraw: func [f act pos][
			if f/state <> f/prev-state [
				f/color: pick f/colors not f/state
				f/font/color: pick f/font/colors not f/state
				f/prev-state: f/state
			]
		]
		engage: func [f act evt][
			if act = 'down [
				if f/parent-face/prev-sel [
					foreach cell f/parent-face/prev-sel [cell/state: off]
					show f/parent-face/prev-sel
				]
				foreach cell f/parent-face/prev-sel: f/row [cell/state: on]
				f/parent-face/selected: f/index
				f/parent-face/picked: pick f/parent-face/data f/index
			]
			show f/row
		]
	]
	
	table-refresh: func [face /hidden /local cell x y txt diff][		
		do bind [
			if prev-sel [foreach cell prev-sel [cell/state: off]]
			either all [data not empty? data][
				if negative? diff: (length? cells) - length? data [
					append cells array/initial reduce [absolute diff length? data/1][]
				]
				for y 1 length? data 1 [
					for x 1 length? data/1 1 [					
						txt: either 'none = txt: data/:y/:x [none][reform txt]
						either object? cells/:y/:x [cells/:y/:x/text: txt][
							append pane cell: make pick columns x [
								row: cells/:y
								color: edge: prev-state: none
								colors: copy reduce [white 0.0.128]
								font: make font [colors: copy reduce [black white]]
								feel: :table-row-feel
								size/y: size/y - 4
								offset/y: offset/y + (size/y * y) + 4
								text: txt
								index: y
							]
							cell/parent-face: :self
							change at cells/:y x cell
						]
					]
				]
				if positive? diff [
					cell: at cells 1 + y: length? data
					while [not tail? cell][
						foreach x cell/1 [remove find pane x]
						cell: next cell
					]
					clear at cells 1 + y
				]
			][
				clear cells
				clear at pane 1 + length? columns
			]
			selected: picked: none
		] in face 'self
		if not hidden [show face]
	]
	
	table-build: func [face def [block!] /local col spec][
		spec: copy [styles win95 origin 0x0 space 0x0 across]
		foreach col def [
			append spec head insert col reduce [face/title-style 'feel [engage: none]]
		]
		insert face/pane face/columns: get in def: layout spec 'pane
		if face/title-style = 'button [
			foreach col face/pane [col/resize col/size * 1x0 + 0x18]
		]
		if not face/size [face/size: def/size * 1x0 + 0x200]
		if negative? face/size/y [face/size: to-pair reduce [def/size/x face/size/x]]
	]
	
	tabs-build: func [face def [block!] /local name blk tab-max tab-face panel-face][
		tab-max: 2x0
		either face/line-list [clear face/line-list][face/line-list: make block! 4]
		foreach [name blk] def [
			tab-face: make templates/tab-text [
				text: name
				font: make templates/tab-text/font face/font
				if not font/colors [font/colors: templates/tab-text/font/colors]
				;para: make para []
				edge: make edge []
				size: (size-text self) + face/para/origin + face/para/margin + 6x3 + 2x2
				size/x: max face/x-max size/x
				offset: tab-max/x * 1x0 + 0x2
				parent-face: :face
			]
			tab-face/edge/effect: get-effect tab-face/size 'tab-bevel
			if not face/selected [face/selected: :tab-face]
			tab-max/x: tab-max/x + tab-face/size/x
			tab-max/y: max tab-max/y tab-face/size/y

			panel-face: make templates/sub-panel [
				action: func [face value] :blk
				styles: face/styles
				edge: make edge []
			]
			do panel-face/init

 			if system/version <= 1.2.8.3.1 [
				panel-face: panel-face/parent-face
			]
			panel-face/size: to-pair reduce [face/size/x - 2 face/size/y - tab-max/y]
			panel-face/offset: 0x1 * tab-max/y
			panel-face/edge/effect: get-effect panel-face/size 'bevel
			append panel-face/edge/effect/draw compose [
				pen (colors/back) box ((val: tab-face/offset/x) * 1x0)
				(val + tab-face/size/x * 1x0 + 0x1)]
			repend face/pane [tab-face panel-face]
			append face/line-list tab-face
		]
	]

	tab-zorder-up: func [face /local list ][
		list: find face/parent-face/pane :face
		repend list [face list/2]
		remove/part list 2
	]

	tab-grow: func [f /local edg val][
		f/size: f/size + 4x4
		f/offset: f/offset - 2x2
		edg: f/edge/effect/draw
		repeat val [6 10 11 17 21 22][poke edg val edg/:val + 4x0]
		if f/font/colors [f/font/color: f/font/colors/2]
		tab-zorder-up f
	]

	tab-shrink: func [f /local edg][
		f/size: f/size - 4x4
		f/offset: f/offset + 2x2
		edg: f/edge/effect/draw
		repeat val [6 10 11 17 21 22][poke edg val edg/:val - 4x0]
		if f/font/colors [f/font/color: f/font/colors/1]
	]

	images: reduce [
		'check make image! reduce [9x9 to-binary decompress #{
			789CFBFF9F34C0C0C0804B1C2E85AC860106D094A189238BA089633587485761
			05006A42B34DF3000000
			}]
		'arrow-down	make image! reduce [7x4 to-binary decompress
			#{789C6360A03E00000054000154000000} 
			#{00000000000000FF0000000000FFFFFF000000FFFFFFFFFF00FFFFFF}
		]
		'radio.off make image! reduce [12x12 to-binary decompress #{
			789CBDD0B10900200C44D1DEA99D2C75C67183530CE8C72058F9CAF31712F7AD
			8227B11738CAF5DA2016496C5A6266D1DC02663F9B973FAFE38CE508D80C9A0C
			62C9D71670EF31524536B0010000
			}]
		'radio.on make image! reduce [12x12 to-binary decompress #{
			789CA590C109C0300CC4FE9D3A93F9ED71B2C135F42011368542F55484639C79
			18201BF61728E57E9DC046129BD98808372528039DB1E13E7F9AB7BFBEECBC8F
			B34C09D82CF410C0A65F5B80FE06D54224DEB0010000
			}]
		'back-slide-img make image! reduce [14x14 to-binary decompress #{
			789CDBBF7FFFFFFFFFF7134112A96C3F188C9A3902CD040060A100534C020000
			}]
	]
	system/view/vid/radio.bmp: images/radio.off
	system/view/vid/radio-on.bmp: images/radio.on
]

templates: stylize [
	text: text
		edge [size: 0x0 color: 0.0.0]
		font [
			name: winskin/font
			size: winskin/font-size
			align: 'left
			valign: 'middle
			shadow: 0x0
			color: winskin/colors/font
		]
		para [wrap?: yes tabs: 16]
		with [color: winskin/colors/back]

	tab-text: text 200x200 no-wrap
		font [colors: reduce [black black]]
		edge [size: 2x2 color: 220.220.220]
		with [
			color: winskin/colors/back
			panel-face: none
			grow: does [winskin/tab-grow self]
			shrink: does [winskin/tab-shrink self]
		]
		feel [
			engage: func [f act evt][
				if act = 'down [
					if f/parent-face/selected [
						f/parent-face/selected/shrink
					]
					f/parent-face/selected: :f
					f/grow
					show f/parent-face
				]
			]
		]

	sub-panel: panel
		edge [
			size: 2x2
			color: 220.220.220
		] with [color: winskin/colors/back]
]


win95: stylize [
	button: button
		font [
			style: none
			name: winskin/font
			size: winskin/font-size
			shadow: 0x0
			color: colors: reduce [winskin/colors/font]
		]
		para [wrap?: no]
		feel [
			prev: false
			over: none
			redraw: func [f act pos][
				if f/state <> prev [
					f/edge/effect: pick f/edge/effects f/state
					all [f/effects f/effect: pick f/effects not f/state]
					if f/texts [f/text: f/texts/1]
					all [f/state f/texts f/text: any [f/texts/2 f/texts/1]]
					prev: f/state
				]
			]
			engage: func [f action event][
				switch action [
					down [f/para/scroll: 1x1 f/state: on]
					alt-down [f/state: on ]
					up [if f/state [f/para/scroll: 0x0 do-face f none] f/state: off]
					alt-up [if f/state [do-face-alt f none] f/state: off]
					over [if not f/state [f/para/scroll: 1x1] f/state: on]
					away [if f/state [f/para/scroll: 0x0] f/state: off]
				]
				cue f action
				show f
			]
		]
		with [
			color: winskin/colors/back
			last-img: none
			resize: func [new][
				size: any [new size]
				edge/effects: winskin/but-effects self
				winskin/but-set-image self
				feel/prev: true
			]
			init: [			
				para: make para []
				edge: make edge [effects: none]
				feel: make feel []
				resize size
				feel/redraw self none none
    		]
    	]

;--- FIELD ---

	field: field 200x20 with [
		font: make templates/text/font []
		colors: reduce [white white]
		append init [
			use [f][
				f: self
				edge: make edge [effect: winskin/ibevel-effect f]
			]
		]
	]	

;--- AREA ---

	area: field
		with [
			size: 400x150
			flags: [field tabbed]
			append init [
				use [f][
					f: self
					edge: make edge [effect: winskin/ibevel-effect f]
				]
			]
		]

;--- RADIO ---

	radio: radio 12x12 with [
		feel: make feel [
			cue: blink: detect: over: none
			redraw: func [face act pos][
				face/image: either face/data [
					winskin/images/radio.on
				][
					winskin/images/radio.off
				]
			]			
			engage: func [face action event][
				if action = 'down [ 
					foreach item face/parent-face/pane [
						if all [
							flag-face? item radio
							item/related = face/related
							item/data
						][
							item/data: false
							show item
						]
					]
					do-face face face/data: true
					show face
				]
			]
		]
		image: winskin/images/radio.off
		saved-area: true
		set [edge font para] none
		flags: [radio]
		init: [effect: [merge key 200.200.200]]
	]

;--- CHECKBOX ---

	check: check 13x13 
		feel [
			redraw: func [face act pos][
				face/image: pick face/images not face/data
			]
		] with [
			edge: make edge []
			color: winskin/colors/field
			images: reduce [none winskin/images/check]
			init: [
				if none? data [data: off]
				edge/effect: winskin/ibevel-effect self
			]
		]

;--- PANEL ---

	panel: panel winskin/colors/back edge [size: 1x1] with [
		append init [
			edge/effect: winskin/get-effect size 'bevel
		]
	]

;--- TAB-PANEL ---

	tab-panel: face 100x100 center
		font [
			style: none
			name: winskin/font
			size: winskin/font-size
			shadow: 0x0
			color: reduce [winskin/colors/font]
			colors: none
		]
		with [
			x-max: 35
			color: none
			selected: none
			init: [
				pane: make block! 20
				winskin/tabs-build self second :action
				selected/grow
			]
			reset: does [set-tab 1]
			set-tab: func [n [integer!]][
				selected/shrink
				selected: any [pick line-list n selected]
				selected/grow
				show self
			]
		]
		
;--- TABLE ---

	table: face 
		font [
			style: none
			name: winskin/font
			size: winskin/font-size
			shadow: 0x0
			color: colors: reduce [winskin/colors/font]
		]
		edge [size: 2x2]
		with [
			columns: cells: prev-sel: picked: selected: none
			color: white
			title-style: 'button
			refresh: does [winskin/table-refresh self]
			resize: func [new][
				size: any [new size]
				edge/effect: winskin/ibevel-effect self
			]
			init: [
				pane: make block! 100
				cells: make block! 10
				winskin/table-build self second :action
				resize size
				refresh
			]
			words: [data [new/data: second args next args]]
		]

;--- ARROW ---

	arrow: button 16x16 with [
		font: make font [align: 'center valign: 'middle]
		image: winskin/images/arrow-down
		append init [		
			state: either all [colors state: pick colors 2] [state] [black]
			fx: select [
				up	  [180	1x0	-1x-2]
				down  [0	0x0	0x0]
				left  [90	0x1	0x-1]
				right [270	1x0	-1x0]
			] data		
			effects/1/2/3: effects/1/2/3 + fx/2
			effects/2/2/3: effects/2/2/3 + fx/3
			fx: reduce ['rotate fx/1]
			append effects/1 fx
			append effects/2 fx				
			state: off
			feel/redraw self none none
		]
        words: [up right down left [new/data: first args args]]
	]

;--- SCROLLER ---

	scroller: scroller effect [tile] winskin/images/back-slide-img with [
		step: .3
	 	init: [
	 		use [svv][
	 			svv: system/view/vid
				pane: reduce [
					make dragger [
						edge: make edge [size: 2x2]
						color: winskin/colors/back
					]
					axis: make win95/arrow [
						dir: -1
						edge: make edge []
						action: get in svvf 'move-drag
						feel: either block? winskin/scroller-feel [
							winskin/scroller-feel: make feel winskin/scroller-feel
						][
							winskin/scroller-feel
						]
					]
					make axis [dir: 1 edge: make edge []]
				]
			]
			if colors [
				color: first colors pane/1/color: second colors
				pane/2/colors: pane/3/colors: append copy at colors 2 pane/2/colors/2
			]
			axis: pick [y x] size/y >= size/x
			resize size
		]
		old-redrag: :redrag
		redrag: func [val /local tmp][
			old-redrag val
       		pane/1/edge/effect: winskin/get-effect pane/1/size 'bevel
       	]
       		
	]


;--- DROPLIST ---		

	droplist: field with [
		list: but-down: max-x: keys: picked: lines: dyn: limit: no-edit: none
		font: make templates/text/font []
		
		words: [
			lines [new/lines: second args next args]
			keys [new/keys: second args next args]
			no-edit [
				new/feel: context [
					redraw: over: detect: none
					engage: func [f a e][
						if a = 'down [						
							either f/list/active? [							
								f/list/active?: no
							][
								f/but-down/action f/but-down none
							] 
						]
					]
				]
				new/no-edit: yes
				args
			]
			dynamic [new/dyn: yes args]
			limit [new/limit: second args next args]
		]
		
		add-item: func [value key][
			append lines value
			append keys key
		]
		reset: does [
			clear lines clear keys
			refresh
		]
		refresh: has [sz][
			max-x: 0
			foreach item lines [
				text: item
				sz: size-text self
				max-x: max max-x first sz
			]
			if dyn [
				size/x: max-x + 16 + (edge/size/x * 2) + but-down/size/x
			]
			list/size: to-pair reduce [
				size/x 16 * (any [limit length? lines ]) + 2
			]
			but-down/offset/x: size/x - 4 - but-down/size/x
			edge/effect: winskin/ibevel-effect self
			text: copy to-string any [pick lines 1 ""]
			picked: none
		]
		
		hide-list: func [face /local window][
			window: last system/view/screen-face/pane
			remove find window/pane face
			winskin/drop-list: none
			face/active?: no
			show window
		]
		
		append init [
			color: pick colors 1
			use [sz item-feel root window][
				root: self
				but-down: make-face/styles/spec 'button win95 [
					text: "v"
					parent-face: root
					image: winskin/images/arrow-down
					size/y: root/size/y - 4
					size/x: 16 ;size/y * 0.90
					offset: 1x0 * (root/size/x - 4 - size/x)
					action: func [face value /local fl sz-y][
						fl: face/parent-face/list
						if fl/scrolling? [state: off exit]
						fl/scrolling?: true
						fl/offset: win-offset? root
						fl/offset/y: fl/offset/y + root/size/y
						sz-y: fl/size/y
						fl/size/y: 2
						
						winskin/drop-list: fl
						window: last system/view/screen-face/pane
						append window/pane fl
						show window
						
						for y 2 sz-y 16 [
							fl/size/y: y
							show fl
							wait 0.01
						]
						fl/scrolling?: false
						fl/active?: yes
					]
					feel: make feel [
						engage: func [f a e][
							switch a [
								down [
									f/state: on					
									either f/parent-face/list/active? [
										f/parent-face/list/active?: no
									][
										do-face f f/text
									]
								]
								up [f/state: off]
								move [if not f/state [f/state: on]]
							]
							show f
    					]
					]
				]
				but-down/text: ""
				pane: but-down
				sz: size
				
				if not root/feel [root/text: any [root/lines/1 ""]]
				
				item-feel: make object! [
					redraw: func [f a pos][
						f/color: pick f/colors f/state
						f/font/color: pick f/font/colors not f/state
					]
					detect: none
					over: func [f a e][
						f/state: a
						show f
					]
					engage: func [f a e][				
						if a = 'down [						
							f/state: off
							root/text: any [all [series? f/text copy f/text] form f/text]
							root/picked: any [
								all [
									in root 'keys
									root/keys
									f/user-data
								]
								f/text
							]
							hide-list root/list
							;f/action f f/text
							do-face root f/text
						]
					]
				]						
				
				list: layout [
					list edge [size: 1x1 color: black][
						origin 0x0
						txt to-pair reduce [sz/x 16] font [
							size: 12 colors: reduce [black white] shadow: none
						] edge [size: 0x0]
					] with [
						arrow: but-down
						parent: root
						scrolling?: 
						active?: no
					] supply [
						face/text: pick root/lines count
						face/text: any [face/text ""]
						face/colors: [0.0.128 255.255.255]
						face/font/size: root/font/size
						face/font/name: root/font/name
						face/font/style: root/font/style
						face/feel: :item-feel
						if root/keys [face/user-data: pick root/keys count]
						if list/scrolling? [face/state: false]
						max-x: max max-x first size-text face						
					]
				]
				list: list/pane/1
				if not lines [
					lines: copy [] keys: copy []
				]
				if string? text [
					append lines text 
					append keys -1
				]
				refresh
			]
		]
	]
]