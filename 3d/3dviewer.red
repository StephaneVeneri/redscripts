Red [
	Title:		"3D wireframe viewer"
	Author:		"Stéphane Vénéri"
	Date:		"08-04-2016"
	Version:	0.1.4
	To-Do:	{
				- Clean the code
				- Improve the IHM
				- Display the model without user's action
				- Automatic resizing model after loading ASC file
				- Make an automatic rotation
			}
	Notes:	{
				This is just an quite fun exercise for me to learn Red.
			}
	Needs:		'View
]


; Constants ---------------------------------------
ANGLE_MAX: 						360
TITLE_APPLICATION:				"3D wireframe viewer"
TITLE_POPUP_ERROR:				"Error"
CHK_OPTIONHIDEFACES:			"Hide faces"
BTN_CLOSE:						"Close"
BTN_QUIT:						"Quit"
MSG_ERR_FILENOTFOUND:			"File not found."
MSG_ERR_BUFFEREMPTY:			"The buffer is empty."
MSG_ERR_MODELNOTLOADED:			"The model wasn't loaded."


; Variables ---------------------------------------
tsin: make block! ANGLE_MAX
tcos: make block! ANGLE_MAX


; Structures --------------------------------------

; Face (todo: add variable for no draw some lines)
face: object [
	nb_vertices:	3
	vertices_index:	[]
]

; Piece of a model
element: object [
	name:			none
	nb_vertices:	0
	nb_faces:		0
	axes:			make vector! [float! 64 3]		; problem see center_repere (to fix)
	vertices:		[]
	faces:			[]
	edges:			[]

	addVertex: function [ x y z ][
		append vertices make vector! reduce [x y z]
	]

	addFace: function [ a b c ][
		append faces make vector! reduce [(a + 1) (b + 1) (c + 1)]
	]

	addEdge: function [ ab bc ca ][
		append edges make vector! reduce [ab bc ca]
	]
]

; Model
model: object [
	nb_elements:	0
	nb_totalfaces:	0
	oelement:		[]

	addElement: function [ elt ][
		append oelement elt
		self/nb_elements: length? oelement			; why self ? else nb_elements = 0 in the main (to understand)
	]
]


; Functions --------------------------------------

precalcul: function [
	"Precalculate table of sin and cos"
] [
	angle: 1
	while [angle <= ANGLE_MAX] [
		value: to-radians angle
		append tsin (sin value)
		append tcos (cos value)
		angle: angle + 1
		;print [angle " " (sin value) " " (cos value)]
	]
]

to-radians: function [
	"Convert degree to radians"
	degree		[integer!]
] [
	return (to-float degree) / 180 * pi
]

to-integer: function [
	"Convert a string to integer"
	str			[any-type!]
][
	return (to integer! str)
]

to-float: function [
	"Convert a string to float"
	str			[any-type!]
][
	return (to float! str)
]

loadASCfile: function [
	"Load ASC file - 3D Studio ascii format"
	ascfile			[file!]
] [
	if not exists? ascfile [ return reduce [#[false] MSG_ERR_FILENOTFOUND] ]
	buffer: read ascfile
	if (length? buffer) = 0 [ return reduce [#[false] MSG_ERR_BUFFEREMPTY] ]

	ws: charset reduce [space tab cr lf newline]
	dstring: charset {"}
	catch_element: [	any [dstring ws] "Tri-mesh"
						thru "Vertices:" [ws | none]
						copy value to ws (
							oneelt: make element [ name: nameelt nb_vertices: to-integer value]
							model/addElement oneelt
						)
						thru "Faces:" [ws | none]
						copy value to ws (
							oneelt/nb_faces: to-integer value
							nbv: oneelt/nb_vertices
							nbf: oneelt/nb_faces
							model/nb_totalfaces: model/nb_totalfaces + nbf
						)
						nbv [ 	thru "X:" [ws | none]
								copy value to ws (cX: to-float value)
								thru "Y:" [ws | none]
								copy value to ws (cY: to-float value)
								thru "Z:" [ws | none]
								copy value to ws (
									cZ: to-float value
									oneelt/addVertex cX cY cZ
								)
						]
						nbf [ 	thru "A:" [ws | none]
								copy value to ws (iA: to-integer value)
								thru "B:" [ws | none]
								copy value to ws (iB: to-integer value)
								thru "C:" [ws | none]
								copy value to ws (iC: to-integer value)
								thru "AB:" [ws | none]
								copy value to ws (vAB: to-integer value)
								thru "BC:" [ws | none]
								copy value to ws (vBC: to-integer value)
								thru "CA:" [ws | none]
								copy value to ws (vCA: to-integer value
									oneface: copy face
									oneelt/addFace iA iB iC
									oneelt/addEdge vAB vBC vCA
									;print [iA iB iC "-" vAB vBC vCA]
								)
						]
	]
	skip_others: [		thru "Position:" [ws | none]
	 					copy value to ws	; it works but I don't like that
						;to "Direct"		; I need to understand why loop on Light02
						;none				; I need to understand why loop on Light01
	]

	parse buffer [
		some [
				thru "Named object:" ws dstring
				copy nameelt to dstring
				catch_element
				|
				skip_others
			]
	]

	[#[true] none]
]


zoom: function[
	value		[float!]
][
	if value <> 0 [
		e: 1
		while [e <= model/nb_elements] [
			i: 1
			while [i <= model/oelement/:e/nb_vertices] [
				model/oelement/:e/vertices/:i: model/oelement/:e/vertices/:i * value
				i: i + 1
			]
			e: e + 1
		]
	]
]


translation: function [
	"Translation on all axes"
	tx			[float!]
	ty			[float!]
	tz			[float!]
][
	; Translation on X
	if tx <> 0 [
		e: 1
		while [e <= model/nb_elements] [
			model/oelement/:e/axes/1: model/oelement/:e/axes/1 + tx
			e: e + 1
		]
	]

	; Translation on Y
	if ty <> 0 [
		e: 1
		while [e <= model/nb_elements] [
			model/oelement/:e/axes/2: model/oelement/:e/axes/2 + ty
			e: e + 1
		]
	]

	; Translation on Z
	if tz <> 0 [
		e: 1
		while [e <= model/nb_elements] [
			model/oelement/:e/axes/3: model/oelement/:e/axes/3 + tz
			e: e + 1
		]
	]
]


center_repere: function [
	"Search the model's repere"
][
	Xmin: model/oelement/1/vertices/1/1
	Ymin: model/oelement/1/vertices/1/2
	Zmin: model/oelement/1/vertices/1/3
	Xmax: Xmin
	Ymax: Ymin
	Zmax: Zmin
	;print ["min X:" Xmin "Y:" Ymin "Z:" Zmin]
	;print ["max X:" Xmax "Y:" Ymax "Z:" Zmax]

	; Search the min and the max value
	e: 1
	while [e <= model/nb_elements] [
		i: 1
		while [i <= model/oelement/:e/nb_vertices] [
			either Xmin > model/oelement/:e/vertices/:i/1
				[ Xmin: model/oelement/:e/vertices/:i/1 ]
				[ if Xmax < model/oelement/:e/vertices/:i/1 [ Xmax: model/oelement/:e/vertices/:i/1 ] ]

			either Ymin > model/oelement/:e/vertices/:i/2
				[ Ymin: model/oelement/:e/vertices/:i/2 ]
				[ if Ymax < model/oelement/:e/vertices/:i/2 [ Ymax: model/oelement/:e/vertices/:i/2 ] ]

			either Zmin > model/oelement/:e/vertices/:i/3
				[ Zmin: model/oelement/:e/vertices/:i/3 ]
				[ if Zmax < model/oelement/:e/vertices/:i/3 [ Zmax: model/oelement/:e/vertices/:i/3 ] ]
			i: i + 1
		]
		e: e + 1
	]

	;print ["min X:" Xmin "Y:" Ymin "Z:" Zmin]
	;print ["max X:" Xmax "Y:" Ymax "Z:" Zmax]

	; Compute the model's repere (center)
	Xmin: (Xmax - Xmin) / 2
	Ymin: (Ymax - Ymin) / 2
	Zmin: (Zmax - Zmin) / 2
	e: 1
	while [e <= model/nb_elements] [
		model/oelement/:e/axes/1: Xmax - Xmin
		model/oelement/:e/axes/2: Ymax - Ymin
		model/oelement/:e/axes/3: Zmax - Zmin
		e: e + 1
	]

	; Compute all vertices with this repere
	e: 1
	while [e <= model/nb_elements] [
		i: 1
		while [i <= model/oelement/:e/nb_vertices] [
			model/oelement/:e/vertices/:i: model/oelement/:e/vertices/:i - model/oelement/:e/axes
			i: i + 1
		]
		; Reset the repere
		;print [e model/oelement/:e/axes]
		;model/oelement/:e/axes: model/oelement/:e/axes * 0		; pointer problem on axes (declaration's pb : to fix)

		e: e + 1
	]
	model/oelement/1/axes: model/oelement/1/axes * 0			; not clean
]


drawModel: function [
	"Draw the model"
	hide		[logic!]		; Hide non-visible faces
][
	area: copy []
	append area [pen green]
	e: 1
	while [e <= model/nb_elements] [
  		i: 1
		while [i <= model/oelement/:e/nb_faces] [
			; Compute the normale
			a: model/oelement/:e/faces/:i/1
			b: model/oelement/:e/faces/:i/2
			c: model/oelement/:e/faces/:i/3
			Xab: model/oelement/:e/vertices/:b/1 - model/oelement/:e/vertices/:a/1
			Yab: model/oelement/:e/vertices/:b/2 - model/oelement/:e/vertices/:a/2
			Xbc: model/oelement/:e/vertices/:c/1 - model/oelement/:e/vertices/:b/1
			Ybc: model/oelement/:e/vertices/:c/2 - model/oelement/:e/vertices/:b/2
			normale: (Xab * Ybc) - (Yab * Xbc)

			; Check if the face is hide
			if any [(normale >= 0 ) (hide = false)] [
				; Search the points' indexes to use
				Xab: model/oelement/:e/axes/1 + model/oelement/:e/vertices/:a/1
				Yab: model/oelement/:e/axes/2 + model/oelement/:e/vertices/:a/2
				Xbc: model/oelement/:e/axes/1 + model/oelement/:e/vertices/:b/1
				Ybc: model/oelement/:e/axes/2 + model/oelement/:e/vertices/:b/2
				Xca: model/oelement/:e/axes/1 + model/oelement/:e/vertices/:c/1
				Yca: model/oelement/:e/axes/2 + model/oelement/:e/vertices/:c/2

				append area reduce ['triangle as-pair Xab Yab as-pair Xbc Ybc as-pair Xca Yca ]
			]

			i: i + 1
		]
		e: e + 1
	]

	return area
]


rotationX: function [
	angle		[integer!]
][
	e: 1
	while [e <= model/nb_elements] [
		i: 1
		while [i <= model/oelement/:e/nb_vertices] [
			pY: model/oelement/:e/vertices/:i/2
			pZ: model/oelement/:e/vertices/:i/3
			;print [pY pZ]
			model/oelement/:e/vertices/:i/2: (pY * (tcos/:angle)) - (pZ * (tsin/:angle))
			model/oelement/:e/vertices/:i/3: (pY * (tsin/:angle)) + (pZ * (tcos/:angle))
			i: i + 1
		]
		e: e + 1
	]
]


rotationY: function [
	angle		[integer!]
][
	e: 1
	while [e <= model/nb_elements] [
		i: 1
		while [i <= model/oelement/:e/nb_vertices] [
			pX: model/oelement/:e/vertices/:i/1
			pZ: model/oelement/:e/vertices/:i/3
			;print [pY pZ]
			model/oelement/:e/vertices/:i/1: (pX * (tcos/:angle)) + (pZ * (tsin/:angle))
			model/oelement/:e/vertices/:i/3: (pZ * (tcos/:angle)) - (pX * (tsin/:angle))
			i: i + 1
		]
		e: e + 1
	]
]


rotationZ: function [
	angle		[integer!]
][
	e: 1
	while [e <= model/nb_elements] [
		i: 1
		while [i <= model/oelement/:e/nb_vertices] [
			pX: model/oelement/:e/vertices/:i/1
			pY: model/oelement/:e/vertices/:i/2
			;print [pY pZ]
			model/oelement/:e/vertices/:i/1: (pX * (tcos/:angle)) - (pY * (tsin/:angle))
			model/oelement/:e/vertices/:i/2: (pX * (tsin/:angle)) + (pY * (tcos/:angle))
			i: i + 1
		]
		e: e + 1
	]
]


popup_alert: function [
	"Display a window with message's error"
	msgerror	[string!]
][
	pop: [
		title TITLE_POPUP_ERROR size 200x100
		below
		text msgerror
		button BTN_CLOSE [ unview ]
	]
	view pop
]


; Main ---------------------------------------------

precalcul
;ret: loadASCfile %cube.asc
ret: loadASCfile %duck.asc
if (ret/1 = false) [
	popup_alert ret/2
	quit
]
if model/nb_elements = 0 [
	popup_alert MSG_ERR_MODELNOTLOADED
	quit
]

; For debug
;probe model

center_repere

; For the duck
zoom 0.1
translation 100.0 75.0 0.0

; For the cube
;zoom 100.0
;translation 320.0 240.0 200.0

; For debug
;area: drawModel true
;probe area

hidefaces: off
view [
	title TITLE_APPLICATION
	bx: base 640x480 black

	below
	bt_rotateX: button "Rotate on X" [
		rotationX 1
		bx/draw: compose/deep [ (drawModel hidefaces) ]
		;wait 0.17
	]
	bt_rotateY: button "Rotate on Y" [
		rotationY 1
		bx/draw: compose/deep [ (drawModel hidefaces) ]
		;wait 0.17
	]
	bt_rotateZ: button "Rotate on Z" [
		rotationZ 1
		bx/draw: compose/deep [ (drawModel hidefaces) ]
		;wait 0.17
	]

	chk_hidefaces: check CHK_OPTIONHIDEFACES data: hidefaces [ hidefaces: (not hidefaces) ]
	bt_quit: button BTN_QUIT [ quit ]
	;text "Number of element: "
]
