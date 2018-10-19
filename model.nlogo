extensions [
 py;
]

breed [sheep a-sheep]
breed [wolves wolf]

turtles-own [ energy ] ;; change to sheep-own?
patches-own [ countdown ]  ;; patches countdown until they regrow

globals [
  max-energy           ;; the maximum amount of energy any animal can have
  min-energy           ;; the minimum amount of energy an animal needs to reproduce
  wolf-gain-from-food  ;; energy units wolves get for eating
  sheep-gain-from-food ;; energy units sheep get for eating
;;  grass-regrowth-time  ;; number of ticks before eaten grass regrows
  breeding-frenzy-freq
  fov-cone-angle
  fov-cone-radius
]

;; add networks,

to-report state ;; a-sheep
  let T ticks mod breeding-frenzy-freq ;; Breeding Timestep
  let enrg energy
  let D heading / 360.
  let P_a (list (xcor / world-width) (ycor / world-height)) ;; Global Position of Agent
  let P_s list 10 10 ;; Relative Position of Closest Sheep
  let P_w list 10 10 ;; Relative Position of Closest Wolf
  let P_g list 10 10 ;; Relative Position of Closest Grass
  let P_sid list 10 10 ;; Relative Position of Closest Sheep in danger

  let sheep_in_cone sheep in-cone fov-cone-radius fov-cone-angle
  set sheep_in_cone other sheep_in_cone ;; Other sheep in cone
  let closest_sheep min-one-of sheep_in_cone [distance myself]
  if closest_sheep != nobody
     [ set P_s list ([xcor] of closest_sheep - xcor) ([ycor] of closest_sheep - ycor)]

  let wolves_in_cone wolves in-cone fov-cone-radius fov-cone-angle
  let closest_wolf min-one-of wolves_in_cone [distance myself]
  if closest_wolf != nobody
      [ set P_w list ([xcor] of closest_wolf - xcor) ([ycor] of closest_wolf - ycor)]

  let grass_in_cone patches in-cone fov-cone-radius fov-cone-angle with [pcolor = green]
  let closest_grass min-one-of grass_in_cone [distance myself]
  if closest_grass != nobody
     [ set P_g list ([pxcor] of closest_grass - xcor) ([pycor] of closest_grass - ycor)]

;;  if closest_wolf != nobody and closest_sheep != nobody
;;    [
;;      let closest_sheep_in_danger min-one-of sheep_in_cone [distance min-one-of wolves_in_cone [distance self]]
;;      set P_sid list ([xcor] of closest_sheep_in_danger - xcor) ([ycor] of closest_sheep_in_danger - ycor)
;;    ]
  report (sentence T D enrg P_a P_s P_w P_g) ;;P_sid)
end

to setup
  clear-all

  py:setup py:python
  (py:run
    "import numpy as np"
    "agent_genomes = {}"
  )

  ;; initialize constant values
  set min-energy 20
  set max-energy 100
  set wolf-gain-from-food 5
  set sheep-gain-from-food 5
  set breeding-frenzy-freq 10
  set fov-cone-angle 30
  set fov-cone-radius 3
;;  set grass-regrowth-time 100 ;; ticks (countdown of path reduced by 1 on each tick)

  ;; setup the grass
  ask patches [ set pcolor green ]
  ask patches [
    set countdown random grass-regrowth-time ;; --> initialize grass grow clocks randomly <-- ??
    if random 2 = 0  ;; half the patches start out with grass
      [ set pcolor brown ]
  ]

  set-default-shape sheep "sheep"
  create-sheep initial-number-sheep  ;; create the sheep, then initialize their variables
  [
    set size 3
    set color white
    set energy random max-energy ;; --> random energy? <--
    setxy round random-xcor round random-ycor
    set heading one-of (list 0 90 180 270)
    py:set "id" who
    (py:run
      "agent_genomes[id] = {'action_net': np.random.rand(11, 5), 'evaluation_net': np.random.rand(11, 1), 'preference_net': np.random.rand(66, 1)}"
      "agent_genomes[id]['initial_action_net'] = np.copy(agent_genomes[id]['action_net'])"
    )
  ]

  set-default-shape wolves "wolf"
  create-wolves initial-number-wolves  ;; create the wolves, then initialize their variables
  [
    set size 3
    set color black
    set energy random max-energy ;; --> random energy? <--
    setxy round random-xcor round random-ycor
    set heading one-of (list 0 90 180 270)
  ]
  reset-ticks
end

to go
  if not any? turtles [ stop ]
  ask sheep [
    move-sheep
    ;; sheep always loose 0.5 units of energy each tick
    set energy energy - 0.5
    eat-grass
    maybe-die
    if ticks mod breeding-frenzy-freq = 0
      [ reproduce-sheep ]
;;    if ticks mod breeding-frenzy-freq = 0
;;      [ show state ]
    ;;(py:run
    ;;  "print vars"
    ;; )
  ]
  ask wolves [
    move-wolf
    ;; wolves always loose 0.5 units of energy each tick
    set energy energy - 0.5
    catch-sheep
    ;;maybe-die: Invincible Wolves...
    ;;reproduce-wolves
  ]
  ask patches [ grow-grass ]
  tick
end

to move-wolf
  ifelse random-float 1 < 0.5
    [ rt 90 ] [ lt 90 ]
  fd 1
end

to move-sheep  ;; turtle procedure
  py:set "agent_id" who
  py:set "agent_state" state
  ;; show state
  let actions py:runresult "np.dot(np.array(agent_state).reshape((1, 11)), agent_genomes[agent_id]['action_net']).flat"

  let max_val max actions
  ;; show max_val
  let argmax_action position max_val actions

  ifelse argmax_action = 0 [ fd 1 ] [
    ifelse argmax_action = 1 [ rt 90 ] [
      ifelse argmax_action = 2 [ lt 90 ] [
        ifelse argmax_action = 3 [ eat-grass ] [
          if argmax_action = 4 [ reproduce ]
        ]
      ]
    ]
  ]
end

to eat-grass  ;; sheep procedure
  ;; sheep eat grass, turn the patch brown
  if pcolor = green [
    set pcolor brown
    set energy energy + sheep-gain-from-food  ;; sheep gain energy by eating
    if energy > max-energy
    [ set energy max-energy ]
  ]
end

to reproduce-sheep  ;; sheep procedure
  reproduce
end

to reproduce-wolves  ;; wolf procedure
  reproduce
end

to reproduce ;; turtle procedure
  set energy (energy - min-reproduce-energy)
  py:set "parent_id" who
  ;; pick a partner


  hatch 1 [
    set heading one-of (list 0 90 180 270)
    set energy min-reproduce-energy
    fd 1
    py:set "id" who
    (py:run
      "agent_genomes[id] = {'action_net': agent_genomes[parent_id]['action_net'] + 0.1 * np.random.rand(11, 5),\\"
      "'evaluation_net': agent_genomes[parent_id]['evaluation_net'] + 0.1 * np.random.rand(11, 1),\\"
      "'preference_net': agent_genomes[parent_id]['preference_net'] + 0.1 * np.random.rand(66, 1)}"
    )
  ]
end

to catch-sheep  ;; wolf procedure
  let prey one-of sheep-here
  if prey != nobody
  [ ask prey [ die ]
    set energy energy + wolf-gain-from-food
    if energy > max-energy [set energy max-energy]
  ]
end

to maybe-die  ;; turtle procedure
  ;; when energy dips below zero, die
  if energy < 0 [
    die
    py:set "dead_sheep" who
    (py:run
      "del agent_genomes[dead_sheep]"
    )
  ]
end

to grow-grass  ;; patch procedure
  ;; countdown on brown patches, if reach 0, grow some grass
  if pcolor = brown [
    ifelse countdown <= 0
      [ set pcolor green
        set countdown grass-regrowth-time ]
      [ set countdown countdown - 1 ]
  ]
end


; Copyright 2006 Uri Wilensky.
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
430
12
804
387
-1
-1
6.0
1
20
1
1
1
0
0
0
1
-30
30
-30
30
1
1
1
ticks
30.0

SLIDER
20
31
201
64
initial-number-sheep
initial-number-sheep
0
250
20.0
1
1
NIL
HORIZONTAL

SLIDER
202
31
382
64
initial-number-wolves
initial-number-wolves
0
250
100.0
1
1
NIL
HORIZONTAL

BUTTON
132
101
201
134
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
202
101
271
134
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
33
265
369
408
populations
time
pop.
0.0
100.0
0.0
100.0
true
true
"" ""
PENS
"sheep" 1.0 0 -13345367 true "" "plot count sheep"
"wolves" 1.0 0 -2674135 true "" "plot count wolves"
"grass / 4" 1.0 0 -10899396 true "" ";; divide by four to keep it within similar\n;; range as wolf and sheep populations\nplot count patches with [ pcolor = green ] / 4"

MONITOR
74
214
152
259
sheep
count sheep
3
1
11

MONITOR
153
214
231
259
wolves
count wolves
3
1
11

MONITOR
232
214
310
259
grass / 4
count patches with [ pcolor = green ] / 4
0
1
11

TEXTBOX
28
11
168
30
Sheep settings
11
0.0
0

TEXTBOX
203
11
316
29
Wolf settings
11
0.0
0

SLIDER
20
65
201
98
initial-sheep-stride
initial-sheep-stride
0
1
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
202
65
383
98
initial-wolf-stride
initial-wolf-stride
0
1
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
8
137
201
170
sheep-stride-length-drift
sheep-stride-length-drift
0
1
0.0
0.01
1
NIL
HORIZONTAL

SWITCH
111
174
307
207
stride-length-penalty?
stride-length-penalty?
0
1
-1000

SLIDER
202
137
395
170
wolf-stride-length-drift
wolf-stride-length-drift
0
1
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
260
498
453
531
grass-regrowth-time
grass-regrowth-time
0
1000
100.0
100
1
NIL
HORIZONTAL

SLIDER
624
513
821
546
min-reproduce-energy
min-reproduce-energy
0
100
5.0
5
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This model is a variation on the predator-prey ecosystems model wolf-sheep predation.
In this model, predator and prey can inherit a stride length, which describes how far forward they move in each model time step.  When wolves and sheep reproduce, the children inherit the parent's stride length -- though it may be mutated.

## HOW IT WORKS

At initialization wolves have a stride of INITIAL-WOLF-STRIDE and sheep have a stride of INITIAL-SHEEP-STRIDE.  Wolves and sheep wander around the world moving STRIDE-LENGTH in a random direction at each step.  Sheep eat grass and wolves eat sheep, as in the Wolf Sheep Predation model.  When wolves and sheep reproduce, they pass their stride length down to their young. However, there is a chance that the stride length will mutate, becoming slightly larger or smaller than that of its parent.

## HOW TO USE IT

INITIAL-NUMBER-SHEEP: The initial size of sheep population
INITIAL-NUMBER-WOLVES: The initial size of wolf population

Half a unit of energy is deducted from each wolf and sheep at every time step. If STRIDE-LENGTH-PENALTY? is on, additional energy is deducted, scaled to the length of stride the animal takes (e.g., 0.5 stride deducts an additional 0.5 energy units each step).

WOLF-STRIDE-DRIFT and SHEEP-STRIDE-DRIFT:  How much variation an offspring of a wolf or a sheep can have in its stride length compared to its parent.  For example, if set to 0.4, then an offspring might have a stride length up to 0.4 less than the parent or 0.4 more than the parent.

## THINGS TO NOTICE

WOLF STRIDE HISTOGRAM and SHEEP STRIDE HISTOGRAM will show how the population distribution of different animal strides is changing.

In general, sheep get faster over time and wolves get slower or move at the same speed.  Sheep get faster in part, because remaining on a square with no grass is less advantageous than moving to new locations to consume grass that is not eaten.  Sheep typically converge on an average stride length close to 1.  Why do you suppose it is not advantageous for sheep stride length to keep increasing far beyond 1?

If you turn STRIDE-LENGTH-PENALTY? off, sheep will become faster over time, but will not stay close to a stride length of 1.  Instead they will become faster and faster, effectively jumping over multiple patches with each simulation step.

## THINGS TO TRY

Try adjusting the parameters under various settings. How sensitive is the stability of the model to the particular parameters?

Can you find any parameters that generate a stable ecosystem where there are at least two distinct groups of sheep or wolves with different average stride lengths?

## EXTENDING THE MODEL

Add a cone of vision for sheep and wolves that allows them to chase or run away from each other.   Make this an inheritable trait.

## NETLOGO FEATURES

This model uses two breeds of turtle to represent wolves and sheep.

## RELATED MODELS

Wolf Sheep Predation, Bug Hunt Speeds

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Novak, M. and Wilensky, U. (2006).  NetLogo Wolf Sheep Stride Inheritance model.  http://ccl.northwestern.edu/netlogo/models/WolfSheepStrideInheritance.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2006 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

<!-- 2006 Cite: Novak, M. -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
setup
repeat 75 [ go ]
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
