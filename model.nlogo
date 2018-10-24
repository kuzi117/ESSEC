extensions [
 py;
 profiler;
]

breed [sheep a-sheep]
breed [wolves wolf]

sheep-own [ energy last_id_of_preferred_sheep_in_cone last_state last_action birth_tick generation last_reward current_state reward_avg reward_count ]
wolves-own [ energy ]
patches-own [ countdown ]  ;; patches countdown until they regrow

globals [
  average_sheep_lifetime
  num_sheep_dead
]

to-report state ;; sheep procedure
  ;; let T ticks
  let enrg energy / sheep-max-energy
  let D heading / 360.
  let P_a (list (xcor / world-width) (ycor / world-height)) ;; Global Position of Agent
  let P_s list 0.0 1.0  ;; Relative Position of Closest Sheep
  let P_w list 0.0 1.0 ;; Relative Position of Closest Wolf
  let P_g list 0.0 1.0 ;; Relative Position of Closest Grass
  ;; let P_sid list 10 10 ;; Relative Position of Closest Sheep in danger

  let sheep_in_cone sheep in-cone sheep-fov-cone-radius sheep-fov-cone-angle
  set sheep_in_cone other sheep_in_cone ;; Other sheep in cone
  let closest_sheep min-one-of sheep_in_cone [distance myself]
  if closest_sheep != nobody  [
    ifelse distance closest_sheep != 0
      ;;[ set P_s list ((sin (towards closest_sheep - heading) * distance closest_sheep) / (sheep-fov-cone-radius + 1))
      ;;               ((cos (towards closest_sheep - heading) * distance closest_sheep) / (sheep-fov-cone-radius + 1))]
      [ set P_s (list ((towards closest_sheep - heading) / 360) (distance closest_sheep / (sheep-fov-cone-radius + 1))) ]
      [ set P_s list 0 0 ]
  ]


  let wolves_in_cone wolves in-cone sheep-fov-cone-radius sheep-fov-cone-angle
  let closest_wolf min-one-of wolves_in_cone [distance myself]
  if closest_wolf != nobody [
    ifelse distance closest_wolf != 0
      ;;[ set P_w list ((sin (towards closest_wolf - heading) * distance closest_wolf) / (sheep-fov-cone-radius + 1))
      ;;               ((cos (towards closest_wolf - heading) * distance closest_wolf) / (sheep-fov-cone-radius + 1))]
      [ set P_w (list ((towards closest_wolf - heading) / 360) (distance closest_wolf / (sheep-fov-cone-radius + 1))) ]
      [ set P_w list 0 0 ]
  ]

  let grass_in_cone patches in-cone sheep-fov-cone-radius sheep-fov-cone-angle with [pcolor = green]
  let closest_grass min-one-of grass_in_cone [distance myself]
  if closest_grass != nobody [
    ifelse distance closest_grass != 0
     ;; [ set P_g list ((sin (towards closest_grass - heading) * distance closest_grass) / (sheep-fov-cone-radius + 1))
     ;;               ((cos (towards closest_grass - heading) * distance closest_grass) / (sheep-fov-cone-radius + 1))]
     [ set P_g (list ((towards closest_grass - heading) / 360) (distance closest_grass / (sheep-fov-cone-radius + 1))) ]
     [ set P_g list 0 0  ]
   ]

;;  if closest_wolf != nobody and closest_sheep != nobody
;;    [
;;      let closest_sheep_in_danger min-one-of sheep_in_cone [distance min-one-of wolves_in_cone [distance self]]
;;      set P_sid list ([xcor] of closest_sheep_in_danger - xcor) ([ycor] of closest_sheep_in_danger - ycor)
;;    ]

  set last_id_of_preferred_sheep_in_cone -1
  let max_pref -1

  if closest_sheep != nobody [
    let sheep_ids [who] of sheep_in_cone
    py:set "sheep_ids_in_cone" sheep_ids
    py:set "this_id" who
    (py:run
      "prefs_info = [(key, agent_preferences[this_id][key]) for key in sheep_ids_in_cone]"
      "max_pref = max([item[1] for item in prefs_info])"
    )
    set max_pref py:runresult "max_pref"
    set last_id_of_preferred_sheep_in_cone py:runresult "prefs_info[np.random.choice(np.flatnonzero(np.array([item[1] for item in prefs_info]) == max_pref))][0]"
  ]

  ;; show (sentence D max_pref enrg P_a P_s P_w P_g)
  ;; report (sentence D max_pref enrg P_a P_s P_w P_g) ;;P_sid)
  ;; show ( sentence 1 max_pref P_s P_w P_g )
  report ( sentence 1 max_pref enrg P_s P_w P_g )
end

to setup
  clear-all

  set average_sheep_lifetime 0
  set num_sheep_dead 0

  py:setup py:python
  (py:run
    "import numpy as np"
    "import ESSEC"
    "agent_genomes = {}"
    "agent_preferences = {}"
    "agent_to_genome = lambda agent: np.concatenate((agent_genomes[agent]['evaluation_net'].flat, agent_genomes[agent]['initial_action_net'].flat))"
    )

  ;; setup the grass
  ask patches [ set pcolor green ]
  ask patches [
    set countdown random grass-regrowth-time ;; --> initialize grass grow clocks randomly <-- ??
    if random 2 = 0  ;; half the patches start out with grass
      [ set pcolor brown ]
  ]

  ifelse sheep-always-eat [
    py:set "num_actions" 4
  ] [
    py:set "num_actions" 5
  ]
  py:set "len_state" 9

  ifelse preference-net-type = "euclidean-distance" [
    py:run "compare_genomes = lambda self, other: np.sqrt(np.sum(np.square(agent_to_genome(self) - agent_to_genome(other))))"
    py:set "len_processed_genomes" 1
  ] [
    ifelse sheep-always-eat [
      py:set "len_processed_genomes" 9 * (4 + 1)
    ] [
      py:set "len_processed_genomes" 9 * (5 + 1)
    ]
    ifelse preference-net-type = "other-genome" [
      py:run "compare_genomes = lambda self, other: agent_to_genome(other)"
    ] [
      ifelse preference-net-type = "absolute-difference" [
        py:run "compare_genomes = lambda self, other: abs(agent_to_genome(self) - agent_to_genome(other))"
      ] [
        py:run "compare_genomes = lambda self, other: np.square(agent_to_genome(self) - agent_to_genome(other))"
      ]
    ]
  ]
  py:run "get_preference = lambda self, other: np.tanh(np.dot(compare_genomes(self, other), agent_genomes[self]['preference_net'])[0] + 1) / 2"
  set-default-shape sheep "default"
  create-sheep sheep-initial-number  ;; create the sheep, then initialize their variables
  [
    set size 3
    set color white
    set energy random sheep-max-energy - sheep-reproduce-energy;; --> random energy? <--
    set energy energy + sheep-reproduce-energy
    setxy round random-xcor round random-ycor
    set heading one-of (list 0 90 180 270)
    set last_state []
    set current_state []
    set reward_avg 0
    set reward_count 0
    py:set "id" who
    set birth_tick 0
    set generation 0
    py:set "random_initial_action_net" random-initial-action-net
    py:set "evolved_preference" evolved-preference
    (py:run
      "action_net = np.random.rand(len_state, num_actions) if random_initial_action_net else np.zeros((len_state, num_actions))"
      "evaluation_net = np.random.rand(len_state, 1)"
      "preference_net = np.random.rand(len_processed_genomes, 1) if evolved_preference else np.zeros((len_processed_genomes, 1))"
      "agent_genomes[id] = {'action_net': action_net, 'evaluation_net': evaluation_net, 'preference_net': preference_net}"
      "agent_genomes[id]['initial_action_net'] = np.copy(agent_genomes[id]['action_net'])"
      "for key in agent_preferences.keys(): agent_preferences[key][id] = get_preference(key, id)"
      "agent_preferences[id] = {key: get_preference(id, key) for key in agent_preferences.keys()}"
    )
  ]

  set-default-shape wolves "default"
  create-wolves wolves-initial-number ;; create the wolves, then initialize their variables
  [
    set size 3
    set color black
    set energy random wolf-reproduce-energy - 1
    setxy round random-xcor round random-ycor
    set heading one-of (list 0 90 180 270)
  ]
  reset-ticks
end

to go
  ;; Stop the simulation if there are no sheep.
  if not any? sheep [ stop ]

  ;; If we're out of wolves, potentially add new wolves
  if not any? wolves and always-have-wolves [
    create-wolves 1 [
      setxy round random-xcor round random-ycor
      set heading one-of (list 0 90 180 270)
      set energy random wolf-reproduce-energy - 1
      set size 3
      set color black
    ]
  ]

  ;; Move wolves first. If a sheep is dumb enough to have stayed where a
  ;; wolf can bite it, then it should be bitten.
  ask wolves [
    ;; Perform our chosen action this step.
    act-wolves

    ;; Die if we don't have enough energy.
    maybe-die-wolves
  ]

  ;; Ask a sheep to act.
  ask sheep [
    set current_state state
    update-action-net
    move-sheep
    maybe-die-sheep
  ]

  ;; Grow grass.
  ask patches [ grow-grass ]

  ;; Step forwards.
  tick
end

to update-action-net  ;; sheep procedure
  if not empty? last_state [
    py:set "agent_last_state" last_state
    py:set "agent_state" current_state
    py:set "last_action" last_action
    py:set "agent_id" who

    ;; L = ((r + gamma * max_a' Q(s', a')) - Q(s, a))**2
    py:set "alpha" alpha
    (py:run
      "value_last_state = np.dot(np.array(agent_last_state).flat, agent_genomes[agent_id]['evaluation_net']).flat[0]"
      "value_state = np.dot(np.array(agent_state).flat, agent_genomes[agent_id]['evaluation_net']).flat[0]"
      "td_error = value_state - value_last_state"
      "q_vals_last_state = np.dot(np.array(agent_last_state).flat, agent_genomes[agent_id]['action_net']).flat"
      "q_vals_state = np.dot(np.array(agent_state).flat, agent_genomes[agent_id]['action_net']).flat"
      "max_q_val = np.max(q_vals_state)"
      "q_val_last_state_action = q_vals_last_state[last_action]"
      "err = td_error + 0.99 * max_q_val - q_val_last_state_action"
      "agent_genomes[agent_id]['action_net'][:, last_action] = agent_genomes[agent_id]['action_net'][:, last_action] + alpha * 1 / len_state * err * np.array(agent_last_state)"
    )

    set last_reward py:runresult "td_error"
    set reward_count (reward_count + 1)
    set reward_avg (reward_avg + (last_reward - reward_avg) / reward_count)
  ]
end

to move-sheep
  py:set "agent_id" who
  py:set "agent_state" current_state
  ;; show state
  let actions py:runresult "np.dot(np.array(agent_state).flat, agent_genomes[agent_id]['action_net']).flat"

  let max_val max actions
  ;; show max_val
  let argmax_action position max_val actions
  ;; show argmax_action

  let action argmax_action
  if random-float 1 < epsilon [
    set action random (length actions)
  ]
  if sheep-always-eat [ eat-grass ]
  ifelse action = 0 [
    fd 1
    set energy energy - sheep-move-cost
  ] [ ifelse action = 1 [
      rt 90
      set energy energy - sheep-move-cost
    ] [ ifelse action = 2 [
        lt 90
        set energy energy - sheep-move-cost
      ] [ ifelse action = 3 [
          maybe-reproduce-sheep
        ] [ if action = 4 [
            eat-grass
          ]
        ]
      ]
    ]
  ]

  set last_state current_state
  set last_action action
end

to eat-grass
  ;; sheep eat grass, turn the patch brown
  if pcolor = green [
    set pcolor brown
    set energy energy + sheep-gain-from-food
    if energy > sheep-max-energy
    [ set energy sheep-max-energy ]
  ]
end

to maybe-reproduce-sheep
  if energy > sheep-reproduce-energy [
    if last_id_of_preferred_sheep_in_cone != -1 [
      set energy (energy - sheep-reproduce-energy)
      py:set "parent_id" who
      let parent_gen generation
      ;; pick a partner
      py:set "partner_id" last_id_of_preferred_sheep_in_cone
      let partner_gen [generation] of turtle last_id_of_preferred_sheep_in_cone
      let max_parent_gen max (list parent_gen partner_gen)
      ;; spawn
      hatch 1 [
        set heading one-of (list 0 90 180 270)
        set energy sheep-reproduce-energy
        fd 1
        py:set "id" who
        set birth_tick ticks
        set generation max_parent_gen + 1
        set reward_avg 0
        set reward_count 0
        ifelse evolved-initial-action-net [ py:set "crossover" 0 ] [ py:set "crossover" 1 ]
        ifelse evolved-preference [ py:set "ev_crossover" 0 ] [ py:set "ev_crossover" 1 ]
        (py:run
          "agent_genomes[id] = {'action_net': 0.5 * agent_genomes[parent_id]['initial_action_net'] + 0.5 *  agent_genomes[partner_id]['initial_action_net'] + \\"
          "0.1 * np.random.rand(len_state, num_actions) * crossover,\\"

          "'evaluation_net': 0.5 * agent_genomes[parent_id]['evaluation_net'] + 0.5 * agent_genomes[partner_id]['evaluation_net'] + \\"
          "0.1 * np.random.rand(len_state, 1),\\"

          "'preference_net': 0.5 * agent_genomes[parent_id]['preference_net'] + 0.5 * agent_genomes[partner_id]['preference_net'] + \\"
          "0.1 * np.random.rand(len_processed_genomes, 1) * ev_crossover}"

          "agent_genomes[id]['initial_action_net'] = np.copy(agent_genomes[id]['action_net'])"
          "for key in agent_preferences.keys(): agent_preferences[key][id] = get_preference(key, id)"
          "agent_preferences[id] = {key: get_preference(id, key) for key in agent_preferences.keys()}"
        )
      ]
    ]
  ]
end

to maybe-die-sheep
  if energy < 0 [
    let lifetime ticks - birth_tick
    set num_sheep_dead (num_sheep_dead + 1)
    let delta (lifetime - average_sheep_lifetime) / num_sheep_dead
    set average_sheep_lifetime average_sheep_lifetime + delta
    py:set "dead_sheep" who
    if count sheep = 1 [
      py:run "print(agent_genomes[dead_sheep], agent_preferences[dead_sheep])"
    ]
    (py:run
      "del agent_genomes[dead_sheep]"
      "del agent_preferences[dead_sheep]"
    )
    die
  ]
end

;; This is all of the wolves' action policy. We prioritise actions
;; in this order: reproduce > attack > turn > move.
to act-wolves ;; Wolf procedure
  ;; If we have enough energy to reproduce, we should reproduce.
  if energy > wolf-reproduce-energy
  [
    set energy energy - wolf-reproduce-cost
    hatch 1 [
      set energy wolf-reproduce-cost
      set heading one-of (list 0 90 180 270)
      fd 1
    ]
    stop
  ]

  ;; If there's a sheep in this tile we should attack.
  ifelse count sheep-here != 0
  [
    ;; Select lowest energy sheep.
    let lowest_sheep min-one-of sheep-here [energy]

    ;; "Attack" it by reducing the sheeps energy while costing us energy.
    ask lowest_sheep [ set energy energy - wolf-attack-damage ]
    set energy energy - wolf-attack-cost

    ;; Feed ourselves if we killed it.
    if [energy] of lowest_sheep <= 0
    [ set energy min list wolf-max-energy (energy + wolf-gain-from-kill) ]

    ;; Ask the sheep to maybe die.
    ask lowest_sheep [ maybe-die-sheep ]

    ;; Don't act in another way
    if not wolves-always-eat [ stop ]
  ]

  ;; If there's no sheep we need to move.
  [
    ifelse not wolves-chase-sheep
    ;; If we're not chasing, move randomly.
    [ move-random-wolves ]

    ;; If we're chasing, chase.
    [
      ;; Get the sheep that we can see.
      let sheep_in_cone sheep in-cone wolf-fov-cone-radius wolf-fov-cone-angle

      ;; Choose our target
      let target_sheep nobody
      ifelse wolves-chase-weakest
      ;; Chase the weakest, set target to closest weakest.
      [
        let closest_sheep sheep_in_cone with-min [distance myself]
        set target_sheep min-one-of closest_sheep [energy]
      ]
      ;; Target a random close sheep.
      [
        set target_sheep min-one-of sheep_in_cone [distance myself]
      ]

      ifelse target_sheep = nobody
      ;; There's no here, move randomly.
      [ move-random-wolves ]

      ;; There's someone here, move towards them.
      [
        ;; towards returns [0, 360)
        let angle_to towards target_sheep

        ;; This holds our desired direction of travel. We use this to
        ;; choose if we're going to move or turn.
        let new_heading 0

        ;; We're going to cut the range [0, 360] into quadrants divided at
        ;; 45 degree points such that we clamp the heading to a cardinal
        ;; direction. Note that the vertical axes are not inclusive of their
        ;; end points, so we prefer movement on the x axis if our target is
        ;; directly on a diagonal.

        ;; If the angle is in [0,45) or (315, 360) then we want to go up.
        if angle_to < 45 or angle_to > 315
        [set new_heading 0]

        ;; If the angle is in [45, 135] we go right.
        if angle_to >= 45 and angle_to <= 135
        [set new_heading 90]

        ;; If the angle is in (135, 225) we go down.
        if angle_to > 135 and angle_to < 225
        [set new_heading 180]

        ;; If the angle is in [225, 315] we go left.
        if angle_to >= 225 and angle_to <= 315
        [set new_heading 270]

        ;; Now check if we're already facing in this direction. If we are, we
        ;; should move, if we aren't then we turn.
        ifelse heading = new_heading
        [ fd 1 ]
        [ set heading new_heading ]
      ]
    ]

    ;; Always cost ourselves the movement cost.
    set energy energy - wolf-move-cost
  ]
end

;; Randomly moves or turns. Does not spend energy.
to move-random-wolves
  ;; 50/50 chance to turn or move.
  ifelse random-float 1 < 0.5
  [
    ;; 50/50 chance to turn left or right.
    ifelse random-float 1 < 0.5
    [ rt 90 ]
    [ lt 90 ]
  ]
  [ fd 1 ]
end

to maybe-die-wolves
  if energy < 0
  [ die ]
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
@#$#@#$#@
GRAPHICS-WINDOW
178
10
597
430
-1
-1
6.74
1
20
1
1
1
0
1
1
1
0
60
0
60
0
0
1
ticks
30.0

SLIDER
6
55
178
88
sheep-initial-number
sheep-initial-number
0
250
100.0
1
1
NIL
HORIZONTAL

SLIDER
6
430
178
463
wolves-initial-number
wolves-initial-number
0
250
1.0
1
1
NIL
HORIZONTAL

BUTTON
384
430
481
463
Reset
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
481
430
578
463
Loop
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
597
10
1089
153
Populations
Time
NIL
0.0
100.0
0.0
100.0
true
true
"" ""
PENS
"Sheep" 1.0 0 -13345367 true "" "plot count sheep"
"Wolves" 1.0 0 -2674135 true "" "plot count wolves"
"Grass / 4" 1.0 0 -10899396 true "" ";; divide by four to keep it within similar\n;; range as wolf and sheep populations\nplot count patches with [ pcolor = green ] / 4"

MONITOR
6
10
69
55
Sheep
count sheep
0
1
11

MONITOR
6
385
69
430
Wolves
count wolves
0
1
11

MONITOR
6
759
77
804
Grass / 4
count patches with [ pcolor = green ] / 4
0
1
11

SLIDER
6
804
178
837
grass-regrowth-time
grass-regrowth-time
0
1000
250.0
25
1
NIL
HORIZONTAL

SLIDER
6
187
178
220
sheep-reproduce-cost
sheep-reproduce-cost
0
100
15.0
1
1
NIL
HORIZONTAL

BUTTON
481
463
578
496
Step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
6
253
178
286
sheep-fov-cone-angle
sheep-fov-cone-angle
0
360
180.0
15
1
NIL
HORIZONTAL

SLIDER
6
286
178
319
sheep-fov-cone-radius
sheep-fov-cone-radius
0
60
10.0
1
1
NIL
HORIZONTAL

SLIDER
6
88
178
121
sheep-gain-from-food
sheep-gain-from-food
0
100
20.0
1
1
NIL
HORIZONTAL

SLIDER
6
220
178
253
sheep-max-energy
sheep-max-energy
0
250
100.0
1
1
NIL
HORIZONTAL

SLIDER
6
154
178
187
sheep-reproduce-energy
sheep-reproduce-energy
0
100
40.0
1
1
NIL
HORIZONTAL

SLIDER
6
726
178
759
wolf-attack-damage
wolf-attack-damage
0
100
20.0
1
1
NIL
HORIZONTAL

SLIDER
6
121
178
154
sheep-move-cost
sheep-move-cost
0
5
0.5
0.25
1
NIL
HORIZONTAL

SLIDER
6
661
178
694
wolf-fov-cone-angle
wolf-fov-cone-angle
0
360
180.0
15
1
NIL
HORIZONTAL

SLIDER
6
319
178
352
alpha
alpha
0
1
0.3
0.01
1
NIL
HORIZONTAL

SLIDER
6
694
178
727
wolf-fov-cone-radius
wolf-fov-cone-radius
0
60
10.0
1
1
NIL
HORIZONTAL

SLIDER
6
352
178
385
epsilon
epsilon
0
1
0.1
0.01
1
NIL
HORIZONTAL

PLOT
597
296
1089
439
Average Sheep Lifetime
Sheep
NIL
0.0
100.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plotxy num_sheep_dead average_sheep_lifetime"

PLOT
597
153
1089
296
Generational Populations
Generation
NIL
0.0
10.0
0.0
30.0
true
false
"" "if min [generation] of sheep != max [generation] of sheep\n[ set-plot-x-range min [generation] of sheep max [generation] of sheep ]"
PENS
"default" 1.0 1 -16777216 true "" "histogram [generation] of sheep"

SWITCH
178
628
368
661
evolved-preference
evolved-preference
0
1
-1000

PLOT
597
439
1089
636
Mean Moving Average of Sheep's Rewards
Time
NIL
0.0
100.0
0.0
10.0
true
true
"set-plot-y-range -2 2\npy:run(\"ESSEC.initStepPlot(50)\")" "py:set \"stepReward\" [last_reward] of sheep\npy:run(\"ESSEC.addStepRewards(stepReward)\")"
PENS
"Window" 1.0 0 -13840069 true "" "plot py:runresult(\"ESSEC.getWindowRewardAvg()\")"
"All Time" 1.0 0 -2674135 true "" "plot py:runresult(\"ESSEC.getAllRewardAvg()\")"
"One Step" 1.0 0 -14835848 true "" "plot mean [last_reward] of sheep"
"All Time Living" 1.0 0 -13345367 true "" "plot mean [reward_avg] of sheep"
"Zero" 1.0 0 -7500403 true "" "plot 0"

BUTTON
384
463
481
496
Profiler
setup                  ;; set up the model\nprofiler:start         ;; start profiling\nrepeat 30 [ go ]       ;; run something you want to measure\nprofiler:stop          ;; stop profiling\nprint profiler:report  ;; view the results\nprofiler:reset         ;; clear the data\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
6
463
178
496
wolf-gain-from-kill
wolf-gain-from-kill
0
100
20.0
1
1
NIL
HORIZONTAL

SLIDER
6
496
178
529
wolf-move-cost
wolf-move-cost
0
5
1.25
0.25
1
NIL
HORIZONTAL

SLIDER
6
562
178
595
wolf-reproduce-energy
wolf-reproduce-energy
0
250
150.0
1
1
NIL
HORIZONTAL

SLIDER
6
595
178
628
wolf-reproduce-cost
wolf-reproduce-cost
0
wolf-reproduce-energy / 2
25.0
1
1
NIL
HORIZONTAL

MONITOR
69
385
178
430
Max Wolf Energy
max [energy] of wolves
0
1
11

SLIDER
6
628
178
661
wolf-max-energy
wolf-max-energy
0
250
200.0
1
1
NIL
HORIZONTAL

MONITOR
69
10
178
55
Max Sheep Energy
max [energy] of sheep
0
1
11

SWITCH
178
463
368
496
wolves-chase-sheep
wolves-chase-sheep
0
1
-1000

SWITCH
178
562
368
595
random-initial-action-net
random-initial-action-net
0
1
-1000

SWITCH
178
595
368
628
evolved-initial-action-net
evolved-initial-action-net
0
1
-1000

SWITCH
178
529
368
562
sheep-always-eat
sheep-always-eat
1
1
-1000

SWITCH
178
430
368
463
always-have-wolves
always-have-wolves
0
1
-1000

SLIDER
7
529
178
562
wolf-attack-cost
wolf-attack-cost
0
5
1.25
.25
1
NIL
HORIZONTAL

SWITCH
178
496
368
529
wolves-always-eat
wolves-always-eat
1
1
-1000

CHOOSER
178
661
368
706
preference-net-type
preference-net-type
"other-genome" "euclidean-distance" "absolute-difference" "squared-difference"
1

MONITOR
1176
112
1339
157
NIL
min [energy] of wolves
0
1
11

SWITCH
1169
186
1386
219
wolves-chase-weakest
wolves-chase-weakest
0
1
-1000

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
<experiments>
  <experiment name="experiment" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count sheep</metric>
    <enumeratedValueSet variable="wolf-fov-cone-angle">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-move-cost">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-always-eat">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evolved-preference">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-always-eat">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-reproduce-cost">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-initial-number">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-attack-cost">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-fov-cone-radius">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fov-cone-radius">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-reproduce-energy">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-gain-from-kill">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-gain-from-food">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-regrowth-time">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evolved-initial-action-net">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-reproduce-cost">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-chase-sheep">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-max-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="always-have-wolves">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-attack-damage">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-reproduce-energy">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-fov-cone-angle">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-initial-number">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-max-energy">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="preference-net-type">
      <value value="&quot;other-genome&quot;"/>
      <value value="&quot;euclidean-distance&quot;"/>
      <value value="&quot;absolute-difference&quot;"/>
      <value value="&quot;squared-difference&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-initial-action-net">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-move-cost">
      <value value="0.5"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
