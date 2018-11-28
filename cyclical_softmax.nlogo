extensions [
  py
  rnd
  profiler
]

breed [ sheep a-sheep ]
breed [ wolves wolf ]

sheep-own [
  energy
  closest_sheep
  last_state
  last_action
  birth_tick
  generation
  last_reward
  current_state
  reward_avg
  reward_count
  parent_id
  oparent_id
  oldest_child_seen
]
wolves-own [ energy ]
patches-own [ countdown ]

globals [
  average_sheep_lifetime
  num_sheep_dead
]

to-report state ;; sheep procedure
  let norm_energy energy / sheep-max-energy

  let P_s list 0.0 1.0
  let preference 0
  set closest_sheep min-one-of other sheep [distance myself]
  if closest_sheep != nobody [
    ifelse distance closest_sheep != 0
      [ set P_s (list ((towards closest_sheep - heading) / 360) (distance closest_sheep / 361)) ]
      [ set P_s list 0 0 ]
    py:set "me" who
    py:set "other" [who] of closest_sheep
    set preference py:runresult "agent_preferences[me][other]"
    if [parent_id] of closest_sheep = who [
      set oldest_child_seen max list oldest_child_seen (ticks - [birth_tick] of closest_sheep)
    ]
  ]

  let P_w list 0.0 1.0
  let closest_wolf min-one-of other wolves [distance myself]
  if closest_wolf != nobody [
    ifelse distance closest_wolf != 0
      [ set P_w (list ((towards closest_wolf - heading) / 360) (distance closest_wolf / 361)) ]
      [ set P_w list 0 0 ]
  ]

  let P_g list 0.0 1.0
  let closest_grass min-one-of patches with [pcolor = green] [distance myself]
  if closest_grass != nobody [
    ifelse distance closest_grass != 0
      [ set P_g (list ((towards closest_grass - heading) / 360) (distance closest_grass / 361)) ]
      [ set P_g list 0 0  ]
  ]

  report ( sentence 1 norm_energy P_s P_w P_g preference (oldest_child_seen / 594.594) )
end

to setup
  clear-all

  set average_sheep_lifetime 0
  set num_sheep_dead 0
  let num_actions 0
  ifelse sheep-always-eat
    [ set num_actions 4 ]
    [ set num_actions 5 ]
  let len_state 10
  let len_transformed_profile 0
  ifelse preference-net-type = "euclidean-distance"
    [ set len_transformed_profile 1 ]
    [ set len_transformed_profile profile-size ]
  let len_profile_genome len_state * (num_actions + 1) + len_transformed_profile

  ;; setup python
  py:setup py:python
  (py:run
    "import numpy as np"
    "import helper"
    "agent_genomes = {}"
    "agent_preferences = {}"
    "agent_to_profile_genome = lambda agent: np.concatenate((agent_genomes[agent]['evaluation_net'].flat, agent_genomes[agent]['initial_action_net'].flat, agent_genomes[agent]['preference_net'].flat))"
    "agent_to_profile = lambda agent: np.dot(agent_to_profile_genome(agent), agent_genomes[agent]['profile_net'])"
  )
  py:set "num_actions" num_actions
  py:set "len_state" len_state
  py:set "len_profile_genome" len_profile_genome
  py:set "profile_size" profile-size
  py:set "len_transformed_profile" len_transformed_profile
  ifelse preference-net-type = "euclidean-distance" [
    py:run "transform_profile = lambda self, other: np.sqrt(np.sum(np.square(agent_to_profile(self) - agent_to_profile(other))))"
  ] [
    ifelse preference-net-type = "other-genome" [
      py:run "transform_profile = lambda self, other: agent_to_profile(other)"
    ] [
      ifelse preference-net-type = "absolute-difference" [
        py:run "transform_profile = lambda self, other: abs(agent_to_profile(self) - agent_to_profile(other))"
      ] [
        py:run "transform_profile = lambda self, other: np.square(agent_to_profile(self) - agent_to_profile(other))"
      ]
    ]
  ]
  py:run "get_preference = lambda self, other: np.tanh(np.dot(transform_profile(self, other), agent_genomes[self]['preference_net'])[0] + 1) / 2"

  ;; setup the sheep
  set-default-shape sheep "default"
  create-sheep sheep-initial-number
  [
    set size 3
    set color white
    set energy random sheep-max-energy - sheep-reproduce-energy
    set energy energy + sheep-reproduce-energy
    setxy round random-xcor round random-ycor
    set heading one-of (list 0 90 180 270)
    set last_state []
    set current_state []
    set reward_avg 0
    set reward_count 0
    py:set "agent_id" who
    set birth_tick 0
    set generation 0
    set parent_id -1
    set oparent_id -1
    py:set "random_initial_action_net" random-initial-action-net
    py:set "random_initial_evaluation_net" random-initial-evaluation-net
    py:set "random_initial_profile_net" random-initial-profile-net
    py:set "random_initial_preference_net" random-initial-preference-net
    (py:run
      "initial_action_net = np.random.rand(len_state, num_actions) if random_initial_action_net else np.zeros((len_state, num_actions))"
      "evaluation_net = np.random.rand(len_state, 1) if random_initial_evaluation_net else np.zeros((len_state, 1))"
      "profile_net = np.random.rand(len_profile_genome, profile_size) if random_initial_profile_net else np.zeros((len_profile_genome, profile_size))"
      "preference_net = np.random.rand(len_transformed_profile, 1) if random_initial_preference_net else np.zeros((len_transformed_profile, 1))"
      "agent_genomes[agent_id] = {'initial_action_net': initial_action_net, 'evaluation_net': evaluation_net, 'profile_net': profile_net, 'preference_net': preference_net}"
      "agent_genomes[agent_id]['action_net'] = np.copy(agent_genomes[agent_id]['initial_action_net'])"
      "for key in agent_preferences.keys(): agent_preferences[key][agent_id] = get_preference(key, agent_id)"
      "agent_preferences[agent_id] = {key: get_preference(agent_id, key) for key in agent_preferences.keys()}"
    )
  ]

  ;; setup the wolves
  set-default-shape wolves "default"
  create-wolves wolves-initial-number ;; create the wolves, then initialize their variables
  [
    set size 3
    set color black
    set energy random wolf-reproduce-energy - 1
    setxy round random-xcor round random-ycor
    set heading one-of (list 0 90 180 270)
  ]

  ;; setup the grass
  ask patches [ set pcolor green ]
  ask patches [
    set countdown random grass-regrowth-time
    if random 2 = 0  ;; half the patches start out with grass
      [ set pcolor brown ]
  ]

  reset-ticks
end

to go
  while [ prevent-singularity ] [ wait 0.1 ]

  if count sheep = 0 [
      stop
  ]

  ;; ensure there's always one wolf
  if not any? wolves and always-have-wolves [
    create-wolves 1 [
      setxy round random-xcor round random-ycor
      set heading one-of (list 0 90 180 270)
      set energy random wolf-reproduce-energy - 1
      set size 3
      set color black
    ]
  ]

  ;; Move wolves first. If a sheep is dumb enough to have stayed where a wolf can bite it, then it should be bitten.
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
      "agent_genomes[agent_id]['action_net'][:, last_action] = agent_genomes[agent_id]['action_net'][:, last_action] - alpha * 1 / len_state * err * np.array(agent_last_state)"
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

  let action 0
  ifelse softmax-on-egreedy-off [
    let denom sum (map exp actions)

    let num (map exp actions)

    let softmax_actions map [x -> x / denom] num

    set action first rnd:weighted-one-of-list (map list (range length actions) softmax_actions) last
  ]
  [
    ifelse random-float 1 < epsilon [
      set actions random (length actions)
    ] [
      let max_val max actions
      ;; show max_val
      let argmax_action position max_val actions
      ;; show argmax_action
      set action argmax_action
    ]
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
  ifelse pcolor = green [
    set pcolor brown
    set energy energy + sheep-gain-from-food
    if energy > sheep-max-energy
    [ set energy sheep-max-energy ]
  ]
  [ set energy energy - sheep-move-cost ]

end

to maybe-reproduce-sheep
  if energy > sheep-reproduce-energy [
    if closest_sheep != nobody [
      set energy (energy - sheep-reproduce-energy)
      let first_parent self
      let partner closest_sheep
      let first_parent_id [who] of first_parent
      let partner_id [who] of partner
      py:set "first_parent_id" first_parent_id
      py:set "partner_id" partner_id
      let first_parent_gen [generation] of first_parent
      let partner_gen [generation] of closest_sheep
      ;; spawn
      hatch 1 [
        set energy sheep-reproduce-energy
        set closest_sheep nobody
        set birth_tick ticks
        set generation 1 + max (list first_parent_gen partner_gen)
        set reward_avg 0
        set reward_count 0
        set parent_id first_parent_id
        set oparent_id partner_id
        set oldest_child_seen 0
        set heading one-of (list 0 90 180 270)
        fd 1
        py:set "child_id" who
        py:set "initial_action_net_mutation" initial-action-net-mutation
        py:set "evaluation_net_mutation" evaluation-net-mutation
        py:set "profile_net_mutation" profile-net-mutation
        py:set "preference_net_mutation" preference-net-mutation
        (py:run
          "agent_genomes[child_id] = {}"
          "agent_genomes[child_id]['initial_action_net'] = 0.5 * agent_genomes[first_parent_id]['initial_action_net'] + 0.5 * agent_genomes[partner_id]['initial_action_net'] + initial_action_net_mutation * np.random.rand(* agent_genomes[first_parent_id]['initial_action_net'].shape)"
          "agent_genomes[child_id]['evaluation_net'] = 0.5 * agent_genomes[first_parent_id]['evaluation_net'] + 0.5 * agent_genomes[partner_id]['evaluation_net'] + evaluation_net_mutation * np.random.rand(* agent_genomes[first_parent_id]['evaluation_net'].shape)"
          "agent_genomes[child_id]['profile_net'] = 0.5 * agent_genomes[first_parent_id]['profile_net'] + 0.5 * agent_genomes[partner_id]['profile_net'] + profile_net_mutation * np.random.rand(* agent_genomes[first_parent_id]['profile_net'].shape)"
          "agent_genomes[child_id]['preference_net'] = 0.5 * agent_genomes[first_parent_id]['preference_net'] + 0.5 * agent_genomes[partner_id]['preference_net'] + preference_net_mutation * np.random.rand(* agent_genomes[first_parent_id]['preference_net'].shape)"
          "agent_genomes[child_id]['action_net'] = np.copy(agent_genomes[child_id]['initial_action_net'])"
          "for key in agent_preferences.keys(): agent_preferences[key][child_id] = get_preference(key, child_id)"
          "agent_preferences[child_id] = {key: get_preference(child_id, key) for key in agent_preferences.keys()}"
        )
      ]
    ]
  ]
end

to-report hazard
  let age ticks - birth_tick
  let will_die false
  let k 10
  let lambda 625
  let h (k / lambda) * ((age / lambda) ^ (k - 1))
  if random-float 1 < h [ set will_die true ]
  report ( will_die )
end

to maybe-die-sheep
  if (energy < 0) or hazard or ticks > 25000 [
    let lifetime ticks - birth_tick
    set num_sheep_dead (num_sheep_dead + 1)
    let delta (lifetime - average_sheep_lifetime) / num_sheep_dead
    set average_sheep_lifetime average_sheep_lifetime + delta

    ;; Dump eulogy.
    py:set "dead_sheep" who
    py:set "parent" parent_id
    py:set "partner" oparent_id
    py:set "age" lifetime
    py:set "gen" generation
    py:set "reward_avg" reward_avg
    py:set "tick" ticks
    py:run "helper.addEulogy(dead_sheep, parent, partner, age, gen, reward_avg, tick)"

    if count sheep = 1  [
      export-all-plots (word "results " date-and-time ".csv")
     (py:run
        "import pickle"
        "filename = helper.getGenomeFileName()"
        "with open(filename, 'wb') as f: pickle.dump(agent_genomes, f)"
        "helper.saveEulogies()"
      )
    ]

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
        let all_closest_sheep sheep_in_cone with-min [distance myself]
        set target_sheep min-one-of all_closest_sheep [energy]
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
    [
      set pcolor green
      set countdown grass-regrowth-time
    ] [
      set countdown countdown - 1
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
446
10
850
415
-1
-1
6.5
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
1
1
1
ticks
30.0

SLIDER
12
10
229
43
sheep-initial-number
sheep-initial-number
0
250
250.0
1
1
NIL
HORIZONTAL

SLIDER
229
10
446
43
wolves-initial-number
wolves-initial-number
0
250
5.0
1
1
NIL
HORIZONTAL

BUTTON
446
415
547
448
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
547
415
648
448
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
976
10
1468
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
850
10
976
55
Sheep
count sheep
0
1
11

MONITOR
850
235
976
280
Wolves
count wolves
0
1
11

MONITOR
850
370
976
415
Grass
count patches with [ pcolor = green ]
0
1
11

SLIDER
229
340
446
373
grass-regrowth-time
grass-regrowth-time
0
1000
400.0
25
1
NIL
HORIZONTAL

SLIDER
12
142
229
175
sheep-reproduce-cost
sheep-reproduce-cost
0
sheep-reproduce-energy
15.0
1
1
NIL
HORIZONTAL

BUTTON
648
415
749
448
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
12
43
229
76
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
12
175
229
208
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
12
109
229
142
sheep-reproduce-energy
sheep-reproduce-energy
0
100
75.0
1
1
NIL
HORIZONTAL

SLIDER
229
307
446
340
wolf-attack-damage
wolf-attack-damage
0
100
40.0
1
1
NIL
HORIZONTAL

SLIDER
12
76
229
109
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
229
241
446
274
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
12
208
229
241
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
229
274
446
307
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
12
241
229
274
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
976
296
1468
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
976
153
1468
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

PLOT
976
439
1468
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
"set-plot-y-range -2 2\npy:run(\"helper.initStepPlot(50)\")" "py:set \"stepReward\" [last_reward] of sheep\npy:run(\"helper.addStepRewards(stepReward)\")"
PENS
"Window" 1.0 0 -13840069 true "" "plot py:runresult(\"helper.getWindowRewardAvg()\")"
"All Time" 1.0 0 -2674135 true "" "plot py:runresult(\"helper.getAllRewardAvg()\")"
"One Step" 1.0 0 -14835848 true "" "plot mean [last_reward] of sheep"
"All Time Living" 1.0 0 -13345367 true "" "plot mean [reward_avg] of sheep"
"Zero" 1.0 0 -7500403 true "" "plot 0"

BUTTON
749
415
850
448
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
229
43
446
76
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
229
76
446
109
wolf-move-cost
wolf-move-cost
0
5
2.0
0.25
1
NIL
HORIZONTAL

SLIDER
229
142
446
175
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
229
175
446
208
wolf-reproduce-cost
wolf-reproduce-cost
0
wolf-reproduce-energy / 2
50.0
1
1
NIL
HORIZONTAL

MONITOR
850
325
976
370
Max Wolf Energy
max [energy] of wolves
0
1
11

SLIDER
229
208
446
241
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
850
100
976
145
Max Sheep Energy
max [energy] of sheep
0
1
11

SWITCH
229
406
446
439
wolves-chase-sheep
wolves-chase-sheep
0
1
-1000

SWITCH
12
439
229
472
random-initial-action-net
random-initial-action-net
0
1
-1000

SWITCH
229
505
446
538
sheep-always-eat
sheep-always-eat
1
1
-1000

SWITCH
229
373
446
406
always-have-wolves
always-have-wolves
0
1
-1000

SLIDER
229
109
446
142
wolf-attack-cost
wolf-attack-cost
0
5
2.0
.25
1
NIL
HORIZONTAL

SWITCH
229
472
446
505
wolves-always-eat
wolves-always-eat
1
1
-1000

CHOOSER
12
571
229
616
preference-net-type
preference-net-type
"other-genome" "euclidean-distance" "absolute-difference" "squared-difference"
1

MONITOR
850
280
976
325
Min Wolf Energy
min [energy] of wolves
0
1
11

SWITCH
229
439
446
472
wolves-chase-weakest
wolves-chase-weakest
1
1
-1000

MONITOR
850
55
976
100
Min Sheep Energy
min [energy] of sheep
17
1
11

MONITOR
850
145
976
190
Min Reproduce Sheep
count sheep with [energy > sheep-reproduce-energy]
0
1
11

MONITOR
850
190
976
235
High Energy Sheep
count sheep with [energy + sheep-gain-from-food > sheep-max-energy]
0
1
11

SWITCH
12
472
229
505
random-initial-evaluation-net
random-initial-evaluation-net
0
1
-1000

SWITCH
12
505
229
538
random-initial-profile-net
random-initial-profile-net
0
1
-1000

SWITCH
12
538
229
571
random-initial-preference-net
random-initial-preference-net
0
1
-1000

SLIDER
12
307
229
340
initial-action-net-mutation
initial-action-net-mutation
0
10
0.1
0.1
1
NIL
HORIZONTAL

SLIDER
12
274
229
307
profile-size
profile-size
0
70
10.0
1
1
NIL
HORIZONTAL

SLIDER
12
340
229
373
evaluation-net-mutation
evaluation-net-mutation
0
10
0.1
0.1
1
NIL
HORIZONTAL

SLIDER
12
373
229
406
profile-net-mutation
profile-net-mutation
0
10
0.1
0.1
1
NIL
HORIZONTAL

SLIDER
12
406
229
439
preference-net-mutation
preference-net-mutation
0
10
0.1
0.1
1
NIL
HORIZONTAL

SWITCH
229
538
446
571
prevent-singularity
prevent-singularity
1
1
-1000

SWITCH
228
571
446
604
softmax-on-egreedy-off
softmax-on-egreedy-off
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
    <enumeratedValueSet variable="random-initial-preference-net">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fov-cone-angle">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-move-cost">
      <value value="1.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="preference-net-mutation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-initial-evaluation-net">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-always-eat">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-reproduce-cost">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-always-eat">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-attack-cost">
      <value value="1.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-initial-number">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-net-mutation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-reproduce-energy">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-gain-from-kill">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fov-cone-radius">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-gain-from-food">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-regrowth-time">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-reproduce-cost">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-action-net-mutation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="always-have-wolves">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-chase-sheep">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-max-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-attack-damage">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profile-net-mutation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-reproduce-energy">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-initial-number">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profile-size">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-chase-weakest">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-initial-profile-net">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-max-energy">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="preference-net-type">
      <value value="&quot;absolute-difference&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prevent-singularity">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-initial-action-net">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-move-cost">
      <value value="0.5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="onerun" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="random-initial-preference-net">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fov-cone-angle">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-move-cost">
      <value value="1.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="preference-net-mutation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-initial-evaluation-net">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-always-eat">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-reproduce-cost">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-always-eat">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-attack-cost">
      <value value="1.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-initial-number">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-net-mutation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fov-cone-radius">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-gain-from-kill">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-reproduce-energy">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-gain-from-food">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-regrowth-time">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-reproduce-cost">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-action-net-mutation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-max-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="always-have-wolves">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-chase-sheep">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-attack-damage">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profile-net-mutation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-reproduce-energy">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-initial-number">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profile-size">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-chase-weakest">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-initial-profile-net">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-max-energy">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="preference-net-type">
      <value value="&quot;absolute-difference&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prevent-singularity">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-initial-action-net">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-move-cost">
      <value value="0.5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="onerun-random-mating" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="random-initial-preference-net">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fov-cone-angle">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-move-cost">
      <value value="1.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="preference-net-mutation">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-initial-evaluation-net">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-always-eat">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-reproduce-cost">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-always-eat">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-attack-cost">
      <value value="1.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-initial-number">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-net-mutation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fov-cone-radius">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-gain-from-kill">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-reproduce-energy">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-gain-from-food">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-regrowth-time">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-reproduce-cost">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-action-net-mutation">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-max-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="always-have-wolves">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-chase-sheep">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-attack-damage">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profile-net-mutation">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-reproduce-energy">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-initial-number">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profile-size">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-chase-weakest">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-initial-profile-net">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-max-energy">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="preference-net-type">
      <value value="&quot;other-genome&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prevent-singularity">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-initial-action-net">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-move-cost">
      <value value="0.5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="csp" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="random-initial-preference-net">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fov-cone-angle">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-move-cost">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="preference-net-mutation">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-initial-evaluation-net">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-reproduce-cost">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-always-eat">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-always-eat">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-attack-cost">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-net-mutation">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-initial-number">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-reproduce-energy">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fov-cone-radius">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-gain-from-kill">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-gain-from-food">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-regrowth-time">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-reproduce-cost">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-action-net-mutation">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-chase-sheep">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="always-have-wolves">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-max-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-attack-damage">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profile-net-mutation">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-reproduce-energy">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-initial-number">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profile-size">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-chase-weakest">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-initial-profile-net">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-max-energy">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="preference-net-type">
      <value value="&quot;euclidean-distance&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="softmax-on-egreedy-off">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-initial-action-net">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prevent-singularity">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-move-cost">
      <value value="0.5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="csr" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="random-initial-preference-net">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fov-cone-angle">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-move-cost">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="preference-net-mutation">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-initial-evaluation-net">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-reproduce-cost">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-always-eat">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-always-eat">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-attack-cost">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaluation-net-mutation">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-initial-number">
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-reproduce-energy">
      <value value="75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-fov-cone-radius">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-gain-from-kill">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-gain-from-food">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-regrowth-time">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-reproduce-cost">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-action-net-mutation">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-chase-sheep">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="always-have-wolves">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sheep-max-energy">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-attack-damage">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profile-net-mutation">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-reproduce-energy">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-initial-number">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="profile-size">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolves-chase-weakest">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-initial-profile-net">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wolf-max-energy">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="preference-net-type">
      <value value="&quot;euclidean-distance&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="softmax-on-egreedy-off">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-initial-action-net">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prevent-singularity">
      <value value="false"/>
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
