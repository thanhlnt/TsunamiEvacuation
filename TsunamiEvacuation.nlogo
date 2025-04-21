extensions [ gis csv bitmap ]

breed [locals local]      ; define new species (breed), named locals who live in the studied area
breed [tourists tourist]  ; define new species (breed), named tourist
breed [cars car]          ; define new species (breed), named cars
breed [rescuers rescuer]  ; define new species (breed), named rescuers (navy, police, red cross, ...)
breed [boats boat]        ; define new species (breed), named boats
globals [
  roads
  buildings
  scale_factor        ; scale factor between GIS coordinates and NetLogo coordinates; unit = meter

  max_number_agents       ; maximum number of agents
  max_distance_shelter
  max_coord_outside

  ;; Patches parameters
  people_patch_threshold ; patch threshold or capability for people

  ;; Global human parameters
  human_speed_std
  human_speed_min ; m/s
  human_speed_max ; m/s

  ;; Global car parameters
  car_speed_std
  car_speed_min  ; m/s
  car_speed_max  ; m/s

  ;; Global tsunami parameters
  tsunami_speed_std


  ;; Locals parameters
  locals_safe         ; number of safe locals
  locals_dead         ; number of dead locals
  locals_in_danger    ; number of in-danger locals

  locals_safe_color
  locals_dead_color
  locals_in_danger_color

  ;; Tourists parameters
  tourists_safe         ; number of safe tourists
  tourists_dead         ; number of dead tourists
  tourists_in_danger    ; number of in-danger tourists

  tourists_safe_color
  tourists_dead_color
  tourists_in_danger_color

  ;; Rescuers parameters
  rescuers_safe         ; number of safe rescuers
  rescuers_dead         ; number of dead rescuers
  rescuers_in_danger    ; number of in-danger rescuers

  rescuers_safe_color
  rescuers_dead_color
  rescuers_in_danger_color

  ;; Cars parameters
  cars_safe       ; number of safe cars
  cars_dead       ; number of dead cars
  cars_in_danger  ; number of in-danger cars

  cars_safe_color
  cars_dead_color
  cars_in_danger_color

  cars_patch_threshold ; patch threshold or capability for cars
  cars_time_wait
  cars_threshold_wait

  ;; Shelters parameters
  shelters               ; collection of the center point of shelters
  shelters_capacity      ; collection of the capacity of shelters
  shelters_nb_people     ; collection of current number people inside a shelters

  ;; Tsunami parameters
  tsunami_length_segment ; length of a segment according to y
  tsunami_curr_coord     ; current coordinate of tsunami
  tsunami_curr_height    ; current height of tsunami - for futher development (Le Thanh)
  tsunami_current_speed  ; current speed of tsunami
  coastal_coord_x        ; x coordinatate of coastal where tsunami begin to decrease the speed


  ;; Building parameters
  building_number
  building_flooded
  building_safe

  ;; Shapefile parameters
  data_dir
  shapefile_road
  shapefile_building
]

;; Define attributes for patches
patches-own[
  flooded?      ; flooded by tsunami or not yet
  road?         ; belong to a road or not
  shelter_id    ; when inside a shelter, which is the id of shelter. Value: -1 or id
  ;safe-zone?   ; inside a shelter or not

  distance_to_safezone ; distance to the nearest shelter, use the breadth-first search algorithm

  ;; attributes for building
  building_id   ; building id
  center_point  ; builidng center point
  ;building?    ; belong to a building or not
]

;; Define common attributes for all agents (locals, tourists, cars, ...)
turtles-own[
  die?
  safe?
  speed         ; current speed of agents
  speed_min     ; minimum speed of agents
  speed_max     ; maximum speed of agents
]

;; Define attributes for locals
locals-own[
]

;; Define attributes for cars
cars-own[
  nb_people_in     ; number of people in a car/car
]

;; Define attributes for tourists
tourists-own[
  ; attributes for strategy 1: tourists wander

  ; attributes for strategy 2: tourists follow locals
  radius_look  ; radius to looking a local person or a rescuer
  leader       ; local person or rescuer that a tourist will follow
]

;; Define attributes for rescuers
rescuers-own[
  nb_tourists  ; number of tourists to rescue
  radius_look  ; radius to looking tourists
]

to setup
  clear-all ;ca
  reset-ticks
  setup-plots

  ;; setup shelter parameters
  set shelters []
  set shelters_capacity []  ;; or array:from-list n-values nb_shelters [0]
  set shelters_nb_people [] ;; or array:from-list n-values nb_shelters [0]

  set data_dir "data/DaNang/"
  set shapefile_road "roads.shp"
  ;set shapefile_building "buildings.shp"

  set max_distance_shelter 100000
  set max_coord_outside -1000
  set max_number_agents (locals_number + tourists_number + cars_number + rescuers_number + boats_number)

  set human_speed_std 0.3
  set human_speed_min 1.4 ; m/s
  set human_speed_max 7.0 ; m/s

  set car_speed_std 0.5
  set car_speed_min 1.4   ; m/s
  set car_speed_max 36.1  ; m/s

  set tsunami_speed_std 0.5

  ;; call setup functions for different species
  setup-map
  ;;setup-building
  setup-patches
  setup-tsunami
  setup-locals
  setup-tourists
  setup-rescuers
  setup-cars

  ;print "READY TO GO ..."
end

to go
  if ticks >= simulation_time [ stop ]

  ;; update locals
  update-locals

  ;; choose tourist strategy
  if tourist_strategy = "wandering" [
    update-tourists-wandering       ; strategy 1: tourists wander
  ]
  if tourist_strategy = "following rescuers or locals" [
    update-tourists-follow-locals-rescuers   ; strategy 2: tourists follow locals
  ]
  if tourist_strategy = "following crowd" [
    update-tourists-follow-crowd    ; strategy 3: tourists follow crowd
  ]

  ;; choose car strategy
  if car_strategy = "always go ahead" [
    update-cars-goahead          ; strategy 1: go ahead if we can go
  ]
  if car_strategy = "change direction when congesion" [
    update-cars-changedirection  ; strategy 2: if we have to wait so long, we will change direction
  ]
  if car_strategy = "go out when congesion" [
    update-cars-goout            ; strategy 3: if we have to wait so long, we will go out and walk
  ]

  ;; update rescuers
  update-rescuers


  ;; update tsunami
  update-tsunami-state

  tick-advance 1
  update-plots
end


;; Setup map: load the shape file
to setup-map
  ;print "setup map ... "
  ;;import-drawing "data/nhatrang/"

  ;; load road
  set roads gis:load-dataset (word data_dir shapefile_road)
  gis:set-world-envelope gis:envelope-of roads

  ;; load buildings
  ;set buildings gis:load-dataset (word data_dir shapefile_building)
  ;;gis:set-world-envelope gis:envelope-of buildings

  ;gis:set-world-envelope (gis:envelope-union-of (gis:envelope-of roads)
  ;                                              (gis:envelope-of buildings))

  let x-ratio (item 1 gis:envelope-of roads - item 0 gis:envelope-of roads) / (max-pxcor - min-pxcor)
  let y-ratio (item 3 gis:envelope-of roads - item 2 gis:envelope-of roads) / (max-pycor - min-pycor)

  ;; the greater ratio defines the correct scale factor between GIS coords and NetLogo coords
  ifelse x-ratio > y-ratio [set scale_factor x-ratio][set scale_factor y-ratio]
  ;print (word "Scale factor: " scale_factor)
end

;; Set up buildings
to setup-building
  ;ask patches [
    ;set building? false
    ;set flooded? false
  ;]
  set building_number 0
  set building_flooded 0
  set building_safe 0

  let id 1
  foreach gis:feature-list-of buildings [ feature ->
    ask patches gis:intersecting feature [
    set center_point gis:location-of gis:centroid-of feature
    ask patch item 0 center_point item 1 center_point [
        set building_id id
        gis:set-drawing-color gray
        gis:fill item (building_id - 1)
        gis:feature-list-of buildings 0.5
        ;set building? true
      ]
    ]
    set id id + 1
  ]
  ;print (word "Number buldings: " count patches with [building_id > 0])
  set building_number count patches with [building_id > 0]
  set building_safe building_number
end

;; Setup patches
to setup-patches
  let patches_color black + 1 ;sky
  let patches_path (word data_dir "patches.png")

  ifelse file-exists? patches_path
  [
    import-pcolors patches_path

    ask patches [
      set road? false
      set flooded? false
      set shelter_id -1
      ;set building_id -1
      ;set building? false
      ;set safe-zone? false

      ;; initialize distance of each patch
      set distance_to_safezone max_distance_shelter
    ]

    ask patches with [ pcolor =  patches_color] [
      set road? true
    ]

  ][
    ask patches [
      set road? false
      set flooded? false
      set shelter_id -1
      ;set building_id -1

      ;set building? false
      ;set safe-zone? false

      ;; initialize distance of each patch
      set distance_to_safezone max_distance_shelter

      if gis:intersects? roads self [
        set pcolor patches_color
        set road? true
      ]

    ]

    export-view patches_path
  ]

  ;prefix streetname ftype etr_id routename route_from route_to owner
  ;print gis:property-names roads
  gis:set-drawing-color white
  gis:draw roads 0.4

  ;;print gis:property-names buildings
  ;gis:set-drawing-color gray
  ;gis:draw buildings 1.0


  ;; count the number of patches belong to road
  ;let no_patch_road 1
  ;ask patches with [ road? ] [
  ;  set no_patch_road no_patch_road + 1
  ;]
  ;print word "Number of patches belongs to roads: " no_patch_road

  ;; setup safe zones
  setup-safe-zones
end

;; Setup safe zones (or shelters) from shelters_x.csv
to setup-safe-zones
  let safe-zones_list csv:from-file (word data_dir "shelters.csv")
  let id 0
  foreach safe-zones_list [ r ->
    let x_safezone item 0 r
    let y_safezone item 1 r
    let sz_width item 2 r
    let sz_height item 3 r
    let sz_capacity item 4 r

    ;; put center of current safezone into shelters
    let center_x round (x_safezone +  sz_width / 2)
    let center_y round (y_safezone - sz_height / 2)
    let center []
    set center lput center_x center ;; adds center_x to the end of list center.
    set center lput center_y center ;; adds center_y to the end of list center

    set shelters lput center shelters ;; put center of current safezone into list of shelters
    set shelters_capacity lput sz_capacity shelters_capacity ;; put capacity of current safezone into list
    set shelters_nb_people lput 0 shelters_nb_people ;; put number people inside current safezone into list

    ;; patches inside safe-zone rectangles
    ask patches with [ (pxcor >= x_safezone and pxcor <= x_safezone + sz_width) and
                       (pycor <= y_safezone and pycor >= y_safezone - sz_height) ]
    [
      set road? false
      ;set safe-zone? true
      set shelter_id id

      ifelse pxcor = item 0 center and pycor = item 1 center [
        set pcolor blue ;red
        set distance_to_safezone 0
      ][
        set pcolor green ;red + 3, 136
      ]
    ]

    set id id + 1

    ;; patches intersect with road, is in red
    ;ask patches with [ safe-zone? and any? neighbors4 with [ road? ] ]
    ;[
    ;  let pt []
    ;  set pt lput pxcor pt
    ;  set pt lput pycor pt
    ;  set shelters lput pt shelters
    ;  set pcolor red ;- 3
    ;  set distance_to_safezone 0 ;; inside a safezone and intersect with road, so distance = 0
    ;]
  ]
  ;; print capacity of shelters
  ;print word "Shelters: " shelters
  ;print word "Shelters capacity: " shelters_capacity
  ;print word "Number current people in shelters: " shelters_nb_people

  ;; update the distance to shelters for all road patches
  let repeatable true
  while [repeatable]
  [
    set repeatable false

    ask patches with [ road? or shelter_id > -1] ;safe-zone?
    [
      let toward_x max_coord_outside
      let toward_y max_coord_outside
      let min_distance distance_to_safezone
      ask neighbors with [ road? or shelter_id > -1 ] ;safe-zone?
      [
        if min_distance > distance_to_safezone + 1
        [
          set min_distance distance_to_safezone + 1
          set toward_x pxcor
          set toward_y pycor
        ]
      ]

      if (toward_x != max_coord_outside) or (toward_y != max_coord_outside)[
        set distance_to_safezone min_distance
        set repeatable true
      ]
    ]
  ]

end

;; Setup tsunami
to setup-tsunami
  set tsunami_length_segment 360 / tsunami_nb_segments

  set tsunami_curr_coord []
  set tsunami_curr_height []
  set tsunami_current_speed []
  set coastal_coord_x []

  ;; generate random x coordinate for tsunami segments
  let id 0
  let max_x_coastal -180
  while [id < tsunami_nb_segments]
  [
    set tsunami_curr_coord lput (max-pxcor + random-normal 20 1) tsunami_curr_coord ;; initial coordinate of a segment
    set tsunami_current_speed lput (random-normal tsunami_speed_avg tsunami_speed_std) tsunami_current_speed

    set max_x_coastal -180
    ask patches with [ (pycor >= tsunami_length_segment * id - 180) and
                       (pycor <= tsunami_length_segment * (id + 1) - 180) and road? = true ]
    [
      if pxcor > max_x_coastal[
        set max_x_coastal pxcor
      ]
    ]
    set coastal_coord_x lput (max_x_coastal + random-normal 20 1) coastal_coord_x

    set id id + 1
  ]
  ;print (word "coastal_coord_x : " coastal_coord_x)

end

;; Setup locals
to setup-locals
  ;; global attributes for locals
  set locals_safe 0
  set locals_in_danger 0
  set locals_dead 0

  set locals_safe_color green
  set locals_dead_color red
  set locals_in_danger_color yellow

  set people_patch_threshold 10 ; number of people can stand in a patch at the same time

  ;; Coordinates to position locals randomly
  let lim_x_locals -82
  let lim_y_locals 80
  let lim_width_locals 30
  let lim_height_locals 135

  let locals_size ceiling(max_number_agents / locals_number)
  if locals_size > 2.5 [set locals_size 2.5]
  ;if locals_size < 1 [set locals_size 1]

  create-locals locals_number [
    set shape "circle"
    set size locals_size
    set color locals_in_danger_color
    set die? false
    set safe? false
    set speed random-normal human_speed_avg human_speed_std ;human_speed_avg + (-1 + random-float(1)) * human_speed_avg * 0.5
    set speed_min human_speed_min ; m/s
    set speed_max human_speed_max ; m/s

    set locals_in_danger locals_in_danger + 1
  ]

  ;; max patch with road?
  let max_y 0
  ask max-one-of patches with [ road? and pycor < lim_y_locals ] [pycor]
  [ set max_y  pycor]
  let min_y 0
  ask min-one-of patches with [ road? and pycor > lim_y_locals - lim_height_locals] [pycor]
  [ set min_y pycor ]
  let max_x 0
  ask max-one-of patches with [ road? and pxcor < lim_x_locals + lim_width_locals] [pxcor]
  [ set max_x pxcor ]
  let min_x 0
  ask min-one-of patches with [ road? and pxcor > lim_x_locals] [pxcor]
  [ set min_x pxcor ]

  ask locals [
    ;; radius to search for initial position in map
    let radius_initial_position 50 + random(50)

    ;; set initial random positions near the roads
    setxy (min_x + (random (max_x - min_x)) ) (min_y + (random (max_y - min_y ) ) )

    ;; move locals to initial position
    let target-patch one-of (patches in-radius radius_initial_position with [
      road?
      and count turtles-here < people_patch_threshold
      and pycor < lim_y_locals and pycor > lim_y_locals - lim_height_locals
      and pxcor > lim_x_locals and pxcor < lim_x_locals + lim_width_locals
    ])

    if target-patch != nobody  [
      move-to target-patch
    ]
  ]
end

;; Setup tourists
to setup-tourists
  ;; global attributes for tourists
  set tourists_safe 0
  set tourists_in_danger 0
  set tourists_dead 0

  set tourists_safe_color green
  set tourists_dead_color red
  set tourists_in_danger_color violet;orange, 42

  ;; coordinates to position tourists randomly
  let lim_x_tourists -55
  let lim_y_tourists 80
  let lim_width_tourists 10
  let lim_height_tourists 135

  let tourists_size ceiling(max_number_agents / tourists_number)
  if tourists_size > 2.5 [set tourists_size 2.5]
  ;if tourists_size < 1 [set tourists_size 1]

  create-tourists tourists_number [
    set shape "circle"
    set size tourists_size
    set color tourists_in_danger_color
    set die? false
    set safe? false
    set speed random-normal human_speed_avg human_speed_std
    set speed_min human_speed_min ; m/s
    set speed_max human_speed_max ; m/s

    set tourists_in_danger tourists_in_danger + 1

    ;; attributes for strategy 2: follow a local person or rescuer
    set radius_look random-normal 15 2
    set leader nobody
  ]

  ;; max patch with road?
  let max_y 0
  ask max-one-of patches with [ road? and pycor < lim_y_tourists ] [pycor]
  [ set max_y  pycor]
  let min_y 0
  ask min-one-of patches with [ road? and pycor > lim_y_tourists - lim_height_tourists] [pycor]
  [ set min_y pycor ]
  let max_x 0
  ask max-one-of patches with [ road? and pxcor < lim_x_tourists + lim_width_tourists] [pxcor]
  [ set max_x pxcor ]
  let min_x 0
  ask min-one-of patches with [ road? and pxcor > lim_x_tourists] [pxcor]
  [ set min_x pxcor ]

  ask tourists [
    ;; radius to search for initial position in map
    let radius_initial_position 50 + random(50)

    ;; set initial random positions near the roads
    setxy (min_x + (random (max_x - min_x )) ) (min_y + (random (max_y - min_y ) ) )

    ;; move tourists to intial position
    let target-patch one-of (patches in-radius radius_initial_position with [
      road?
      and count turtles-here < people_patch_threshold
      and pycor < lim_y_tourists and pycor > lim_y_tourists - lim_height_tourists
      and pxcor > lim_x_tourists and pxcor < lim_x_tourists + lim_width_tourists
    ])

    if target-patch != nobody  [
      move-to target-patch
    ]
  ]
end

to setup-rescuers
  ;; global attributes for rescuers
  set rescuers_safe 0
  set rescuers_in_danger 0
  set rescuers_dead 0

  set rescuers_safe_color green
  set rescuers_dead_color red
  set rescuers_in_danger_color turquoise

  ;; coordinates to position tourists randomly
  let lim_x_rescuers -55
  let lim_y_rescuers 80
  let lim_width_rescuers 10
  let lim_height_rescuers 135

  let rescuers_size ceiling(max_number_agents / rescuers_number)
  if rescuers_size > 2.5 [set rescuers_size 2.5]
  ;if rescuers_size < 1 [set rescuers_size 1]

  create-rescuers rescuers_number [
    set shape "circle"
    set size rescuers_size
    set color rescuers_in_danger_color
    set die? false
    set safe? false
    set speed random-normal human_speed_avg human_speed_std
    set speed_min human_speed_min ; m/s
    set speed_max human_speed_max ; m/s

    set nb_tourists 0
    set radius_look random-normal 15 2

    set rescuers_in_danger rescuers_in_danger + 1
  ]

  ;; max patch with road?
  let max_y 0
  ask max-one-of patches with [ road? and pycor < lim_y_rescuers ] [pycor]
  [ set max_y  pycor]
  let min_y 0
  ask min-one-of patches with [ road? and pycor > lim_y_rescuers - lim_height_rescuers] [pycor]
  [ set min_y pycor ]
  let max_x 0
  ask max-one-of patches with [ road? and pxcor < lim_x_rescuers + lim_width_rescuers] [pxcor]
  [ set max_x pxcor ]
  let min_x 0
  ask min-one-of patches with [ road? and pxcor > lim_x_rescuers] [pxcor]
  [ set min_x pxcor ]

  ask rescuers [
    ;; radius to search for initial position in map
    let radius_initial_position 50 + random(50)

    ;; set initial random positions near the roads
    setxy (min_x + (random (max_x - min_x )) ) (min_y + (random (max_y - min_y ) ) )

    ;; move rescuers to intial position
    let target-patch one-of (patches in-radius radius_initial_position with [
      road?
      and count turtles-here < people_patch_threshold
      and pycor < lim_y_rescuers and pycor > lim_y_rescuers - lim_height_rescuers
      and pxcor > lim_x_rescuers and pxcor < lim_x_rescuers + lim_width_rescuers
    ])

    if target-patch != nobody  [
      move-to target-patch
    ]
  ]
end


;; Setup cars
to setup-cars
  ;; global attributes for cars
  set cars_safe 0
  set cars_in_danger 0
  set cars_dead 0

  set cars_safe_color green
  set cars_dead_color red
  set cars_in_danger_color brown ;orange, 44

  set cars_patch_threshold 1 ; number of cars can stand in a patch at the same time
  set cars_time_wait 0
  set cars_threshold_wait 5

  ;; coordinates to position cars randomly
  let lim_x_cars -82
  let lim_y_cars 80
  let lim_width_cars 50
  let lim_height_cars 135

  let size_cars ceiling(max_number_agents / cars_number)
  if size_cars > 4.5 [set size_cars 4.5]
  ;if size_cars < 1 [set size_cars 1]

  create-cars cars_number [
    set shape "car"
    set size size_cars
    set color cars_in_danger_color
    set die? false
    set safe? false
    set speed random-normal car_speed_avg car_speed_std ; car_speed_avg + (-1 + random-float(5)) * car_speed_avg * 0.5
    set speed_min car_speed_min
    set speed_max car_speed_max

    set cars_in_danger cars_in_danger + 1
    set nb_people_in 1 + random(4)
  ]

  ;; max patch with road?
  let max_y 0
  ask max-one-of patches with [ road? and pycor < lim_y_cars ] [pycor]
  [ set max_y  pycor]
  let min_y 0
  ask min-one-of patches with [ road? and pycor > lim_y_cars - lim_height_cars] [pycor]
  [ set min_y pycor ]
  let max_x 0
  ask max-one-of patches with [ road? and pxcor < lim_x_cars + lim_width_cars] [pxcor]
  [ set max_x pxcor ]
  let min_x 0
  ask min-one-of patches with [ road? and pxcor > lim_x_cars] [pxcor]
  [ set min_x pxcor ]

  ask cars [
    ;; radius to search for initial position in map
    let radius_initial_position 50 + random(50)

    ;; set initial random positions near the roads
    setxy (min_x + (random (max_x - min_x )) ) (min_y + (random (max_y - min_y ) ) )

    ;; move cars to intial position
    let target-patch one-of (patches in-radius radius_initial_position with [
      road?
      and count cars-here < cars_patch_threshold
      and pycor < lim_y_cars and pycor > lim_y_cars - lim_height_cars
      and pxcor > lim_x_cars and pxcor < lim_x_cars + lim_width_cars
    ])

    if target-patch != nobody  [
      move-to target-patch
    ]
  ]
end


;; Update state of tsunami
to update-tsunami-state
  if ticks >= tsunami_approach_time [
    ;; update properties of tsunami segments
    let tsunami_speed_scale 0
    let nb_building_flooded 0
    let tmp 0
    let id 0
    while [id < tsunami_nb_segments] [
      ifelse item id tsunami_curr_coord >= item id coastal_coord_x [
        set tmp random-normal tsunami_speed_avg 20
        set tsunami_current_speed replace-item id tsunami_current_speed tmp
      ][
        ;; Decrease tsunami speed toward 0
        if item id tsunami_current_speed > 0 [
          set tmp item id tsunami_current_speed - random(20) - 10
          set tsunami_current_speed replace-item id tsunami_current_speed tmp
          if item id tsunami_current_speed < 0 [
            set tsunami_current_speed replace-item id tsunami_current_speed 0
          ]
        ]
      ]

      ;print (word "tsunami_current_speed: of a segment" item id tsunami_current_speed)
      set tsunami_speed_scale (item id tsunami_current_speed * scale_factor * 60 / 3.6) ;; tsunami speed (pixels/update)

      ;; update current coordinate of tsunami
      set tmp item id tsunami_curr_coord - tsunami_speed_scale
      set tsunami_curr_coord replace-item id tsunami_curr_coord tmp

      ask patches with [ pxcor >= item id tsunami_curr_coord + random(10) and
                        (pycor >= tsunami_length_segment * id - 180) and
                        (pycor <= tsunami_length_segment * (id + 1) - 180) ] [
        if shelter_id = -1 and flooded? = false and random(10) < 2  [
          set pcolor blue
          set flooded? true ;; pcolor 96
        ]
        if flooded? = true and random(10) < 2 [
          set pcolor blue - 2.5
        ]
        ;if building_id > 0 [
        ;  set building_flooded building_flooded + 1
        ;]
      ]

      if item id tsunami_current_speed = 0 [
        ask patches with [pxcor >= item id tsunami_curr_coord and
          (pycor >= tsunami_length_segment * id - 180) and
          (pycor <= tsunami_length_segment * (id + 1) - 180) and
          shelter_id = -1 and flooded? = true] [
          set pcolor blue - 2.5
        ]
      ]

      ask patches with [ building_id > 0 and flooded? = true ][
        gis:set-drawing-color red
        gis:fill item (building_id - 1)
        gis:feature-list-of buildings 0.5
      ]
      set nb_building_flooded nb_building_flooded + count patches with [ pxcor >= item id tsunami_curr_coord and
                                                (pycor >= tsunami_length_segment * id - 180) and
                                                (pycor <= tsunami_length_segment * (id + 1) - 180) and
                                                building_id > 0 ]



      set id id + 1
    ]

    set building_flooded nb_building_flooded
    set building_safe building_number - building_flooded
  ]
end

;; Update distance to safe zone when a shelter is full
to update-shelter-full [ id ]

  ask patches with [shelter_id = id][
    set shelter_id -1
    set distance_to_safezone max_distance_shelter
  ]

  ask patches with [ road? or shelter_id > -1 ] [
    set distance_to_safezone max_distance_shelter
  ]

  let i 0
  foreach shelters [point ->
    if (item i shelters_nb_people < item i shelters_capacity)
    [
       ask patch item 0 point item 1 point[
         set distance_to_safezone 0
       ]
    ]
    ;[
    ;  ask patch item 0 point item 1 point[
    ;    print word "Full shelters: " self
    ;    set shelter_id -1
    ;    set distance_to_safezone max_distance_shelter
    ;   ]
    ;]

    set i i + 1
  ]

  ;; update the distance to shelters for all road patches
  let repeatable true
  while [repeatable]
  [
    set repeatable false

    ask patches with [ road? or shelter_id > -1] ;safe-zone?
    [
      let toward_x max_coord_outside
      let toward_y max_coord_outside
      let min_distance distance_to_safezone
      ask neighbors with [ road? or shelter_id > -1 ] ;safe-zone?
      [
        if (min_distance > distance_to_safezone + 1) [
          set min_distance distance_to_safezone + 1
          set toward_x pxcor
          set toward_y pycor
        ]
      ]

      if (toward_x != max_coord_outside) or (toward_y != max_coord_outside)[
        set distance_to_safezone min_distance
        set repeatable true
      ]
    ]
  ]
end

;; Update state of locals
to update-locals
  ;; If locals are not yet evacuated, they must move
  ;; If a local person has already been evacuated, he/she moves inside the evacuation area
  ;; If he/she died, he/she does not move

  ;; update alive locals
  ask locals with [ die? = false ]
  [

    ;; manage locals state
    let hasToDie false
    let isSafe safe?

    ask patch-here
    [
      if flooded?[
        set locals_dead locals_dead + 1
        set locals_in_danger locals_in_danger - 1
        set hasToDie true
      ]

      if hasToDie = false [
        ;; if change from safe-zone to road
        ifelse isSafe = true and road? [
          set locals_in_danger locals_in_danger + 1
          set isSafe false
        ][
          ;; if change from road to safe-zone
          if isSafe = false and  shelter_id > -1[ ;safe-zone?
            set locals_in_danger locals_in_danger - 1
            set isSafe true
          ]
        ]
      ]
    ]

    ifelse hasToDie
    [
      set color locals_dead_color
      set die? true
      set safe? false
    ][
      set safe? isSafe
      if safe? [set color locals_safe_color ]
    ]

    ;; move locals behaviour if they are still alive
    if die? = false and safe? = false
    [
      ;; find the neighbor with min distance to safezone
      let min_neighbor_distance max_distance_shelter
      let neighbor_x max_coord_outside
      let neighbor_y max_coord_outside

      ask neighbors with [ can-people-move-to-patch self ] ; ask 8 surrounding patches
      [
        if min_neighbor_distance > distance_to_safezone
        [
          set min_neighbor_distance distance_to_safezone
          set neighbor_x pxcor
          set neighbor_y pycor
        ]
      ]

      if (min_neighbor_distance != max_distance_shelter and distance_to_safezone > 0) ; found a patch that it can move on
      [
        set speed random-normal speed 1
        if speed < speed_min [set speed speed_min] ; 5km/h is the speed of walking - minimum speed of people
        if speed > speed_max [set speed speed_max] ; maximum speed of people
        move-to-patch speed patch neighbor_x neighbor_y

        ask patch-here [
          if (shelter_id > -1) [ ;safe-zone?
            let tmp item shelter_id shelters_nb_people + 1
            set shelters_nb_people replace-item shelter_id shelters_nb_people tmp
            ;print word "Number current people in shelters (by adding a person): " shelters_nb_people

            if (item shelter_id shelters_nb_people > item shelter_id shelters_capacity) [
              update-shelter-full shelter_id ;; update distance to safezone
            ]
          ]
        ]
      ]
    ]
  ]

end

;; Strategy 1: the tourists will wander
to update-tourists-wandering
  ;; If tourists are not yet evacuated, they must move
  ;; If a tourist has already been evacuated, he/she moves inside the evacuation area
  ;; If he/she died, he/she does not move

  ;; update alive tourists
  ask tourists with [ die? = false ]
  [
    ;; manage tourists state
    let hasToDie false
    let isSafe safe?

    ask patch-here
    [
      if flooded?[
        set tourists_dead tourists_dead + 1
        set tourists_in_danger tourists_in_danger - 1
        set hasToDie true
      ]

      if hasToDie = false [
        ;; if change from safe-zone to road
        ifelse isSafe = true and road? [
          set tourists_in_danger tourists_in_danger + 1
          set isSafe false
        ][
          ;; if change from road to safe-zone
          if isSafe = false and shelter_id > -1[ ;safe-zone?
            set tourists_in_danger tourists_in_danger - 1
            set isSafe true
          ]
        ]
      ]
    ]

    ifelse hasToDie
    [
      set color tourists_dead_color
      set die? true
      set safe? false
    ][
      set safe? isSafe
      if safe? [set color tourists_safe_color ]
    ]

    ;; move tourists behaviour if they are still alive
    if die? = false and safe? = false
    [
      let neighbor_x max_coord_outside
      let neighbor_y max_coord_outside

      let angle_look 0
      let repeatable true
      while [repeatable]
      [
        ask patch-right-and-ahead angle_look 1
        [
          ifelse (can-people-move-to-patch self)
          [
            set neighbor_x pxcor
            set neighbor_y pycor
            set repeatable false
          ][
            set angle_look (angle_look + 45) mod 360
            if angle_look = 0 [ set repeatable false ]
          ]
        ]
      ]


      if (neighbor_x != max_coord_outside and distance_to_safezone > 0)  ; found a patch that it can move on
      [
        set speed random-normal speed 1
        if speed < speed_min [set speed speed_min] ; 5km/h is the speed of walking - minimum speed of people
        if speed > speed_max [set speed speed_max] ; maximum speed of people

        move-to-patch speed patch neighbor_x neighbor_y

        ask patch-here [
          if (shelter_id > -1) [ ;safe-zone?
            let tmp item shelter_id shelters_nb_people + 1
            set shelters_nb_people replace-item shelter_id shelters_nb_people tmp
            ;print word "Number current people in shelters (by adding a tourist): " shelters_nb_people

            if (item shelter_id shelters_nb_people > item shelter_id shelters_capacity) [
              update-shelter-full shelter_id ;; update distance to safezone
            ]
          ]
        ]
      ]
    ]
  ]
end


;; Strategy 2: the tourists will follow a local person
to update-tourists-follow-locals-rescuers

  ;; update alive tourists
  ask tourists with [ die? = false ]
  [
    ;; manage tourists state
    let hasToDie false
    let isSafe safe?

    ask patch-here
    [
      if flooded?[
        set tourists_dead tourists_dead + 1
        set tourists_in_danger tourists_in_danger - 1
        set hasToDie true
      ]

      if hasToDie = false [
        ;; if change from safe-zone to road
        ifelse isSafe = true and road? [
          set tourists_in_danger tourists_in_danger + 1
          set isSafe false
        ][
          ;; if change from road to safe-zone
          if isSafe = false and  shelter_id > -1[ ;safe-zone?
            set tourists_in_danger tourists_in_danger - 1
            set isSafe true
          ]
        ]
      ]
    ]

    ifelse hasToDie
    [
      set color tourists_dead_color
      set die? true
      set safe? false
    ][
      set safe? isSafe
      if safe? [set color tourists_safe_color ]
    ]

    ;; move tourists behaviour if they are still alive
    if die? = false and safe? = false
    [
      set speed random-normal speed 1
      if speed < speed_min [set speed speed_min] ; 5km/h is the speed of walking - minimum speed of people
      if speed > speed_max [set speed speed_max] ; maximum speed of people

      ifelse leader = nobody
      [
        ; find a local person (the leader) to follow
        let candidate nobody
        ;let radius 1
        ;while [radius < radius_look]
        ;[
          set candidate one-of (rescuers in-radius radius_look)
          if candidate = nobody [
            set candidate one-of (locals in-radius radius_look)
          ]

          ;ifelse candidate = nobody
          ;[
          ;  set radius radius + 1
          ;][
          ;  set radius radius_look + 1
          ;]
        ;]

        ifelse candidate = nobody
        [
          let neighbor_x max_coord_outside
          let neighbor_y max_coord_outside

          let angle_look 0
          let repeatable true
          while [repeatable]
          [
            ask patch-right-and-ahead angle_look 1
            [
              ifelse (can-people-move-to-patch self)
              [
                set neighbor_x pxcor
                set neighbor_y pycor
                set repeatable false
              ][
                set angle_look (angle_look + 45) mod 360
                if angle_look = 0 [ set repeatable false ]
              ]
            ]
          ]

          if (neighbor_x != max_coord_outside and distance_to_safezone > 0)  ; found a patch that it can move on
          [
            move-to-patch speed patch neighbor_x neighbor_y
          ]
        ][
          set leader candidate
          move-to-patch speed leader ; follow the leader
        ]

      ][
        move-to-patch speed leader   ; follow the leader
      ]

      ask patch-here [
        if (shelter_id > -1) [ ;safe-zone?
          let tmp item shelter_id shelters_nb_people + 1
          set shelters_nb_people replace-item shelter_id shelters_nb_people tmp
          ;print word "Number current people in shelters (by adding a tourist): " shelters_nb_people

          if (item shelter_id shelters_nb_people > item shelter_id shelters_capacity) [
            update-shelter-full shelter_id ;; update distance to safezone
          ]
        ]
      ]
    ]
  ]
end

; Strategy 3: the tourists will  follow crowd
to update-tourists-follow-crowd
  ;; update alive tourists
  ask tourists with [ die? = false ]
  [
    ;; manage tourists state
    let hasToDie false
    let isSafe safe?

    ask patch-here
    [
      if flooded?[
        set tourists_dead tourists_dead + 1
        set tourists_in_danger tourists_in_danger - 1
        set hasToDie true
      ]

      if hasToDie = false [
        ;; if change from safe-zone to road
        ifelse isSafe = true and road? [
          set tourists_in_danger tourists_in_danger + 1
          set isSafe false
        ][
          ;; if change from road to safe-zone
          if isSafe = false and  shelter_id > -1[ ;safe-zone?
            set tourists_in_danger tourists_in_danger - 1
            set isSafe true
          ]
        ]
      ]
    ]

    ifelse hasToDie
    [
      set color tourists_dead_color
      set die? true
      set safe? false
    ][
      set safe? isSafe
      if safe? [set color tourists_safe_color ]
    ]

    ;; move tourists behaviour if they are still alive
    if die? = false and safe? = false
    [
      set speed random-normal speed 1
      if speed < speed_min [set speed speed_min] ; 5km/h is the speed of walking - minimum speed of people
      if speed > speed_max [set speed speed_max] ; maximum speed of people

      ;let neighbor_x max_coord_outside
      ;let neighbor_y max_coord_outside

      let centroid_distance radius_look / 2
      let centroid_radius radius_look / 2
      let angle_look 0
      let nb_crowd -1
      let max_nb_crowd -1
      let best_angle -1
      let repeatable true
      let can_move_angle false
      while [repeatable]
      [
        ask patch-right-and-ahead angle_look 1
        [
          ifelse (can-people-move-to-patch self)
          [
            set can_move_angle true
          ][
            set can_move_angle false
          ]
        ]
        if can_move_angle [
          ask patch-right-and-ahead angle_look centroid_distance
          [
            set nb_crowd (count tourists in-radius centroid_radius + count locals in-radius centroid_radius)
            if nb_crowd > max_nb_crowd [
              set max_nb_crowd nb_crowd
              set best_angle angle_look
            ]
          ]
        ]

        set angle_look (angle_look + 45) mod 360
        if angle_look = 0 [ set repeatable false ]
      ]

      if best_angle > -1 [
        move-to-patch speed patch-right-and-ahead best_angle 1
      ]

      ;print word "Max number people: " max_nb_crowd
      ;print word "Best angle: " best_angle

      ask patch-here [
        if (shelter_id > -1) [ ;safe-zone?
          let tmp item shelter_id shelters_nb_people + 1
          set shelters_nb_people replace-item shelter_id shelters_nb_people tmp
          ;print word "Number current people in shelters (by adding a tourist): " shelters_nb_people

          if (item shelter_id shelters_nb_people > item shelter_id shelters_capacity) [
            update-shelter-full shelter_id ;; update distance to safezone
          ]
        ]
      ]
    ]
  ]
end


to update-rescuers
  ;; If rescuers will wander to find tourists

  ;; update alive rescuers
  ask rescuers with [ die? = false ]
  [
    ;; manage rescuers state
    let hasToDie false
    let isSafe safe?

    ask patch-here
    [
      if flooded?[
        set rescuers_dead rescuers_dead + 1
        set rescuers_in_danger rescuers_in_danger - 1
        set hasToDie true
      ]

      if hasToDie = false [
        ;; if change from safe-zone to road
        ifelse isSafe = true and road? [
          set rescuers_in_danger rescuers_in_danger + 1
          set isSafe false
        ][
          ;; if change from road to safe-zone
          if isSafe = false and shelter_id > -1[ ;safe-zone?
            set rescuers_in_danger rescuers_in_danger - 1
            set isSafe true
          ]
        ]
      ]
    ]

    ifelse hasToDie
    [
      set color rescuers_dead_color
      set die? true
      set safe? false
    ][
      set safe? isSafe
      if safe? [set color rescuers_safe_color ]
    ]

    ;; move tourists behaviour if they are still alive
    if die? = false and safe? = false
    [
      let neighbor_x max_coord_outside
      let neighbor_y max_coord_outside

      set nb_tourists count tourists in-radius radius_look
      ifelse (nb_tourists > 0)[ ; go to safezones

        ;; find the neighbor with min distance to safezone
        let min_neighbor_distance max_distance_shelter

        ask neighbors with [ can-people-move-to-patch self ] ; ask 8 surrounding patches
        [
          if min_neighbor_distance > distance_to_safezone
          [
            set min_neighbor_distance distance_to_safezone
            set neighbor_x pxcor
            set neighbor_y pycor
          ]
        ]

        if (min_neighbor_distance != max_distance_shelter and distance_to_safezone > 0) ; found a patch that it can move on
        [
          set speed random-normal speed 1
          if speed < speed_min [set speed speed_min] ; 5km/h is the speed of walking - minimum speed of people
          if speed > speed_max [set speed speed_max] ; maximum speed of people
          move-to-patch speed patch neighbor_x neighbor_y

          ask patch-here [
            if (shelter_id > -1) [ ;safe-zone?
              let tmp item shelter_id shelters_nb_people + 1
              set shelters_nb_people replace-item shelter_id shelters_nb_people tmp

              if (item shelter_id shelters_nb_people > item shelter_id shelters_capacity) [
                update-shelter-full shelter_id ;; update distance to safezone
              ]
            ]
          ]
        ]
      ][
        ; wandering
        let angle_look 0
        let repeatable true
        while [repeatable]
        [
          ask patch-right-and-ahead angle_look 1
          [
            ifelse (can-people-move-to-patch self)
            [
              set neighbor_x pxcor
              set neighbor_y pycor
              set repeatable false
            ][
              set angle_look (angle_look + 45) mod 360
              if angle_look = 0 [ set repeatable false ]
            ]
          ]
        ]

        if (neighbor_x != max_coord_outside and distance_to_safezone > 0)  ; found a patch that it can move on
        [
          set speed random-normal (1.2 * speed) 1
          if speed < speed_min [set speed speed_min] ; 5km/h is the speed of walking - minimum speed of people
          if speed > speed_max [set speed speed_max] ; maximum speed of people

          move-to-patch speed patch neighbor_x neighbor_y

          ask patch-here [
            if (shelter_id > -1) [ ;safe-zone?
              let tmp item shelter_id shelters_nb_people + 1
              set shelters_nb_people replace-item shelter_id shelters_nb_people tmp

              if (item shelter_id shelters_nb_people > item shelter_id shelters_capacity) [
                update-shelter-full shelter_id ; update distance to safezone
              ]
            ]
          ]
        ]
      ]
    ]
  ]
end

;; Strategy 1: cars go ahead forever (acceleration or deceleration)
to update-cars-goahead
  ;; If cars are not yet evacuated, they must move
  ;; If it died, it does not move

  ;; update alive cars
  ask cars with [ die? = false ]
  [
    ;; manage agent state
    let hasToDie false
    let isSafe safe?

    ask patch-here
    [
      if flooded?[
        set cars_dead cars_dead + 1
        set cars_in_danger cars_in_danger - 1
        set hasToDie true
      ]

      if hasToDie = false [
        ;; if change from safe-zone to road
        ifelse isSafe = true and road? [
          set cars_in_danger cars_in_danger + 1
          set isSafe false
        ][
          ;; if change from road to safe-zone
          if isSafe = false and  shelter_id > -1[
            set cars_in_danger cars_in_danger - 1
            set isSafe true
          ]
        ]
      ]
    ]

    ifelse hasToDie
    [
      set color cars_dead_color
      set die? true
      set safe? false
    ][
      set safe? isSafe
      if safe? [set color cars_safe_color ]
    ]

    ;; move cars behaviour if they are still alive
    if die? = false and safe? = false
    [
      ;; find the neighbor with min distance to safezone
      let min_neighbor_distance max_distance_shelter
      let neighbor_x max_coord_outside
      let neighbor_y max_coord_outside

      ask neighbors with [ can-cars-move-to-patch self ]  ; ask 8 surrounding patches
      [
        if min_neighbor_distance > distance_to_safezone
        [
          set min_neighbor_distance distance_to_safezone
          set neighbor_x pxcor
          set neighbor_y pycor
        ]
      ]

      if (min_neighbor_distance != max_distance_shelter and distance_to_safezone > 0) [
        let car_ahead one-of cars-on patch-ahead 1
        ifelse car_ahead != nobody
        [
          ; slow down so you are driving more slowly than the car ahead of you
          set speed [ speed ] of car_ahead - car_deceleration
        ][
          ; otherwise, speed up
          set speed speed + car_acceleration
        ]
        ; don't slow down below speed minimum or speed up beyond speed limit
        ifelse speed < speed_min [
          set speed speed_min
        ][
          if speed > speed_max [ set speed speed_max ]
        ]

        move-to-patch speed patch neighbor_x neighbor_y

        let tmp_nb_people nb_people_in

        ask patch-here [
          if (shelter_id > -1) [ ;safe-zone?
            let tmp item shelter_id shelters_nb_people + tmp_nb_people
            set shelters_nb_people replace-item shelter_id shelters_nb_people tmp
            ;print word "Number current people in shelters (by adding a car): " shelters_nb_people

            if (item shelter_id shelters_nb_people > item shelter_id shelters_capacity) [
              update-shelter-full shelter_id ;; update distance to safezone
            ]
          ]
        ]
      ]

    ]
  ]

end

;; Strategy 2: cars will change direction if they wait so long
to update-cars-changedirection

end

to update-cars-goout

  let stopcarsX []        ;; x coordinate of cars with speed = 0
  let stopcarsY []        ;; y coordinate of cars with speed = 0
  let stopcarsNbPeople [] ;; number of people inside cars with speed = 0

  ;; update alive cars
  ask cars with [die? = false]
  [
    ;; manage agent state
    let hasToDie false
    let isSafe safe?

    ask patch-here
    [
      if flooded?[
        set cars_dead cars_dead + 1
        set cars_in_danger cars_in_danger - 1
        set hasToDie true
      ]

      if hasToDie = false [
        ;; if change from safe-zone to road
        ifelse isSafe = true and road? [
          set cars_in_danger cars_in_danger + 1
          set isSafe false
        ][
          ;; if change from road to safe-zone
          if isSafe = false and  shelter_id > -1[
            set cars_in_danger cars_in_danger - 1
            set isSafe true
          ]
        ]
      ]
    ]

    ifelse hasToDie
    [
      set color cars_dead_color
      set die? true
      set safe? false
    ][
      set safe? isSafe
      if safe? [set color cars_safe_color ]
    ]

    ;; move cars behaviour if they are still alive
    if die? = false and safe? = false and speed > 0
    [
      ;; find the neighbor with min distance to safezone
      let min_neighbor_distance max_distance_shelter
      let neighbor_x max_coord_outside
      let neighbor_y max_coord_outside

      ask neighbors with [ can-cars-move-to-patch self ]  ; ask 8 surrounding patches
      [
        if min_neighbor_distance > distance_to_safezone
        [
          set min_neighbor_distance distance_to_safezone
          set neighbor_x pxcor
          set neighbor_y pycor
        ]
      ]

      if (min_neighbor_distance != max_distance_shelter and distance_to_safezone > 0) [
        let car_ahead one-of cars-on patch-ahead 1
        ifelse car_ahead != nobody
        [
          ; slow down so you are driving more slowly than the car ahead of you
          set speed [ speed ] of car_ahead - car_deceleration
        ][
          ; otherwise, speed up
          set speed speed + car_acceleration
          set cars_time_wait 0
        ]
        ; don't slow down below speed minimum or speed up beyond speed limit
        ifelse speed < speed_min [
          set speed speed_min
          set cars_time_wait cars_time_wait + 1
        ][
          if speed > speed_max [ set speed speed_max ]
        ]

        ifelse cars_time_wait < cars_threshold_wait[
          move-to-patch speed patch neighbor_x neighbor_y

          let tmp_nb_people nb_people_in

          ask patch-here [
            if (shelter_id > -1) [ ;safe-zone?
              let tmp item shelter_id shelters_nb_people + tmp_nb_people
              set shelters_nb_people replace-item shelter_id shelters_nb_people tmp
              ;print word "Number current people in shelters (by adding a car): " shelters_nb_people

              if (item shelter_id shelters_nb_people > item shelter_id shelters_capacity) [
                update-shelter-full shelter_id ;; update distance to safezone
              ]
            ]
          ]
        ][
          set speed 0

          set stopcarsX lput xcor stopcarsX
          set stopcarsY lput ycor stopcarsY
          set stopcarsNbPeople lput nb_people_in stopcarsNbPeople
        ]
      ]
    ]
  ]

  let i 0
  while [i < length stopcarsNbPeople] [
    create-locals item i stopcarsNbPeople [
      set shape "circle"
      set size 5
      set color locals_in_danger_color
      set die? false
      set safe? false
      set speed random-normal human_speed_avg human_speed_std
      set speed_min human_speed_min
      set speed_max human_speed_max
      setxy item i stopcarsX item i stopcarsY

      set locals_number locals_number + 1
    ]
    set i i + 1
  ]

end


;; Given a point, return true if a person can move to it, false elsewhere
to-report can-people-move-to-patch [ point ]
  let can_move false

  ask point [
    ifelse shelter_id > -1 ;safe-zone?
    [
      if can-move-into-shelter point [
        set can_move true
      ]
    ][
      if road? and flooded? = false and count turtles-here <= people_patch_threshold [
        set can_move true
      ]
    ]
  ]

  report can_move
end

;; Given a point, return true if current car can move to it, false elsewhere
to-report can-cars-move-to-patch [ point ]
  let can_move false

  ask point [
    ifelse shelter_id > -1 ;safe-zone?
    [
      if can-move-into-shelter point [
        set can_move true
      ]
    ][
      if road? and flooded? = false and count cars-here <= cars_patch_threshold [
        set can_move true
      ]
    ]
  ]

  report can_move
end

;; Given a safe point inside a shelter, return true if current people can move to it, false elsewhere
to-report can-move-into-shelter [ safe_point ]
  let can_move false

  ask safe_point[
    if (item shelter_id shelters_nb_people < item shelter_id shelters_capacity)[
      set can_move true
      ;print word "Can move to shelters: " shelter_id
    ]
  ]
  report can_move
end

;; Move agents to target_patch and forward with speed spd +- random value
;; spd is peed of agents, not scale speed
to move-to-patch [ spd target_patch ]
  if target_patch != nobody [
    face target_patch

    ;; update current speed (scale) of agent
    let speed_scale 0.3 * spd * scale_factor * 60 / 3.6

    ;; move agent to target with current speed
    forward speed_scale
  ]
end


;; Given a point, return the id of nearest shelter to this point
;to-report get-id-nearest-shelter [ point ]
;  let id -1
;  let min_distance max_distance_shelter
;  let tmp_distance max_distance_shelter
;  let i 0
;  ask point[
;    foreach shelters [ a_shelter ->
;      set tmp_distance distance patch item 0 a_shelter item 1 a_shelter
;      if (min_distance > tmp_distance)[
;        set min_distance tmp_distance
;        set id i
;      ]
;      set i i + 1
;    ]
;  ]
;  report id
;end
@#$#@#$#@
GRAPHICS-WINDOW
329
15
1107
794
-1
-1
2.133
1
14
1
1
1
0
1
1
1
-180
180
-180
180
0
0
1
ticks
30.0

BUTTON
2
18
155
76
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

INPUTBOX
0
90
97
150
locals_number
20.0
1
0
Number

BUTTON
160
17
310
75
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

MONITOR
1225
18
1351
67
Evacuated Locals
locals_number - (locals_in_danger + locals_dead)
17
1
12

MONITOR
1119
18
1223
67
Dead Locals
locals_dead
17
1
12

MONITOR
1343
18
1477
67
In-danger Locals
locals_in_danger
17
1
12

PLOT
1119
69
1479
258
Dead vs Evacuated vs In-danger Locals
Time (seconds)
# Locals
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Evacuated" 1.0 0 -13840069 true "" "plot count locals with [ safe? = true ]"
"Dead" 1.0 0 -2674135 true "" "plot count locals with [ die? = true ]"
"In-danger" 1.0 0 -1184463 true "" "plot locals_in_danger"

PLOT
739
862
1105
1035
Tsunami Average Velocity
Time (seconds)
Velocity
0.0
10.0
0.0
200.0
true
false
"" ""
PENS
"tsunami speed" 1.0 0 -13840069 true "" "if tsunami_current_speed != 0 [plot mean(tsunami_current_speed)]"

MONITOR
332
809
452
858
Total Buildings
building_number
17
1
12

MONITOR
455
809
578
858
Flooded Buildings
building_flooded
17
1
12

MONITOR
580
809
692
858
Safe Buildings
building_safe
17
1
12

PLOT
333
860
693
1036
Flooded vs. Safe Buildings
Time (seconds)
# Buildings
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Flooded" 1.0 0 -2674135 true "" "plot building_flooded"
"Safe" 1.0 0 -13840069 true "" "plot building_safe"

INPUTBOX
102
90
207
150
tourists_number
10.0
1
0
Number

INPUTBOX
209
90
311
150
cars_number
5.0
1
0
Number

MONITOR
1119
572
1228
621
Flooded Cars
cars_dead
17
1
12

MONITOR
1230
572
1356
621
Evacuated Cars
cars_number - (cars_in_danger + cars_dead)
17
1
12

MONITOR
1355
572
1481
621
In-danger Cars
cars_in_danger
17
1
12

PLOT
1119
623
1482
795
Flooded vs. Evacuated vs. In-danger Cars
Time (seconds)
# Cars
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Evacuated" 1.0 0 -13840069 true "" "plot count cars with [ safe? = true ]"
"Flooded" 1.0 0 -2674135 true "" "plot count cars with [ die? = true ]"
"In-danger" 1.0 0 -1184463 true "" "plot cars_in_danger"

SLIDER
1
356
306
389
car_acceleration
car_acceleration
1
6
5.0
0.1
1
m/s
HORIZONTAL

SLIDER
1
392
306
425
car_deceleration
car_deceleration
1
6
5.0
0.1
1
m/s
HORIZONTAL

SLIDER
0
321
305
354
car_speed_avg
car_speed_avg
16.5
22.5
20.8
0.1
1
m/s
HORIZONTAL

SLIDER
0
599
309
632
simulation_time
simulation_time
600
7200
600.0
60
1
ticks
HORIZONTAL

SLIDER
0
228
305
261
human_speed_avg
human_speed_avg
2.7
6
6.0
0.1
1
m/s
HORIZONTAL

SLIDER
0
488
307
521
tsunami_nb_segments
tsunami_nb_segments
1
10
3.0
1
1
NIL
HORIZONTAL

SLIDER
0
525
307
558
tsunami_speed_avg
tsunami_speed_avg
20
80
44.3
0.1
1
m/s
HORIZONTAL

SLIDER
0
561
307
594
tsunami_approach_time
tsunami_approach_time
440
520
460.0
20
1
s
HORIZONTAL

MONITOR
1492
20
1592
69
Dead Tourists
tourists_dead
17
1
12

MONITOR
1593
20
1727
69
Evacuated Tourists
tourists_number - (tourists_in_danger + tourists_dead)
17
1
12

MONITOR
1729
20
1854
69
In-danger Tourists
tourists_in_danger
17
1
12

PLOT
1492
72
1854
259
Dead vs. Evacuated vs. In-danger Tourists
Time (seconds)
# Tourists
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Evacuated" 1.0 0 -13840069 true "" "plot count tourists with [ safe? = true ]"
"Dead" 1.0 0 -2674135 true "" "plot count tourists with [ die? = true ]"
"In-danger" 1.0 0 -1184463 true "" "plot tourists_in_danger"

CHOOSER
0
265
305
310
tourist_strategy
tourist_strategy
"wandering" "following rescuers or locals" "following crowd"
1

CHOOSER
0
427
308
472
car_strategy
car_strategy
"always go ahead" "change direction when congesion" "go out when congesion"
0

INPUTBOX
0
158
96
218
rescuers_number
10.0
1
0
Number

INPUTBOX
101
158
206
218
boats_number
0.0
1
0
Number

MONITOR
1493
572
1587
617
Dead Rescuers
rescuers_dead
17
1
11

MONITOR
1590
572
1718
617
On-duty Rescuers
rescuers_number - rescuers_dead
17
1
11

PLOT
1493
619
1853
794
Dead vs. Working Rescuers
Time (seconds)
# Rescuers
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Dead" 1.0 0 -2674135 true "" "plot rescuers_dead"
"On-duty" 1.0 0 -14439633 true "" "plot (rescuers_number - rescuers_dead)"

MONITOR
739
810
923
859
Tsunami Average Velocity
mean(tsunami_current_speed)
17
1
12

PLOT
1119
272
1479
468
Percentage of Dead Locals vs. Tourists
Time (seconds)
# Casualties
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Locals" 1.0 2 -1184463 true "" "plot 100 * (count locals with [ die? = true ]) / locals_number"
"Tourists" 1.0 0 -8630108 true "" "plot 100 * (count tourists with [ die? = true ]) / tourists_number"

PLOT
1492
272
1855
468
Percentage of Evacuated Locals vs. Tourists
Time (seconds)
# Saved Lives
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Locals" 1.0 0 -1184463 true "" "plot 100 * (count locals with [safe? = true ]) / locals_number"
"Tourists" 1.0 0 -8630108 true "" "plot 100 * (count tourists with [safe? = true ]) / tourists_number"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)
Click SETUP button, then click GO button

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
NetLogo 6.2.0
@#$#@#$#@
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
