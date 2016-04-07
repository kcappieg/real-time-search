#!/bin/bash

PLOTS_DIR=plots
DURATIONS=(20000000 40000000 80000000 160000000 320000000)
ALGORITHMS=""

add_algorithm() {
  if [ -z "$1" ]; then
    >&2 echo "Internal script error: missing parameter to $FUNCNAME"
    exit 1
  else
    ALGORITHMS="$ALGORITHMS -a $1"
  fi
}

add_algorithm "LSS_LRTA_STAR"
add_algorithm "RTA_STAR"
add_algorithm "DYNAMIC_F_HAT"
add_algorithm "A_STAR"
add_algorithm "ARA_STAR"

make_graphs() {
  if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    >&2 echo "Internal script error: missing parameter to $FUNCNAME"
    exit 1
  else
    DOMAIN="$1"
    INSTANCE="$2"
    FILE_HEADER="$3"
    MD=""

    FILE="$PLOTS_DIR/${FILE_HEADER}_error.pdf"
    ./rtsMongoClient.py $ALGORITHMS -d "$DOMAIN" -i "$INSTANCE" -t "gatPerDuration" -s "$FILE" -q $@
    MD="${MD}![$INSTANCE]($FILE)\n\n"

    for duration in ${DURATIONS[@]}; do
      FILE="$PLOTS_DIR/${FILE_HEADER}_${duration}.pdf"
      ./rtsMongoClient.py $ALGORITHMS -d "$DOMAIN" -i "$INSTANCE" -c "$duration" -t "gatBoxPlot" -s "$FILE" -q $@
      MD="${MD}![$INSTANCE]($FILE)\n\n"

      FILE="$PLOTS_DIR/${FILE_HEADER}_${duration}_bars.pdf"
      ./rtsMongoClient.py $ALGORITHMS -d "$DOMAIN" -i "$INSTANCE" -c "$duration" -t "gatBars"    -s "$FILE" -q $@
      MD="${MD}![$INSTANCE]($FILE)\n\n"

      FILE="$PLOTS_DIR/${FILE_HEADER}_${duration}_violin.pdf"
      ./rtsMongoClient.py $ALGORITHMS -d "$DOMAIN" -i "$INSTANCE" -c "$duration" -t "gatViolin"  -s "$FILE" -q $@
      MD="${MD}![$INSTANCE]($FILE)\n\n"
    done

    echo "$MD"
  fi
}

if [ ! -d "$PLOTS_DIR" ]; then
  mkdir "$PLOTS_DIR"
fi

# Grid World
GRID_WORLD_MD=""
GRID_WORLD_MD="${GRID_WORLD_MD}$(make_graphs "GRID_WORLD" "input/vacuum/dylan/slalom.vw" "dylan_slalom")"
GRID_WORLD_MD="${GRID_WORLD_MD}$(make_graphs "GRID_WORLD" "input/vacuum/dylan/uniform.vw" "dylan_uniform")"
GRID_WORLD_MD="${GRID_WORLD_MD}$(make_graphs "GRID_WORLD" "input/vacuum/dylan/cups.vw" "dylan_cups")"
GRID_WORLD_MD="${GRID_WORLD_MD}$(make_graphs "GRID_WORLD" "input/vacuum/dylan/wall.vw" "dylan_wall")"


# Sliding Tile Puzzle
PUZZLE_MD=""
for ((i=1; i <= 100; i++)); do
  PUZZLE_MD="${PUZZLE_MD}$(make_graphs "SLIDING_TILE_PUZZLE_4" "input/tiles/korf/4/all/$i" "tiles_${i}")"
done

# Point Robot
PR_MD=""
PR_MD="${PR_MD}$(make_graphs "POINT_ROBOT" "input/pointrobot/dylan/slalom.pr" "pr_dylan_slalom")"
PR_MD="${PR_MD}$(make_graphs "POINT_ROBOT" "input/pointrobot/dylan/uniform.pr" "pr_dylan_uniform")"
PR_MD="${PR_MD}$(make_graphs "POINT_ROBOT" "input/pointrobot/dylan/cups.pr" "pr_dylan_cups")"
PR_MD="${PR_MD}$(make_graphs "POINT_ROBOT" "input/pointrobot/dylan/wall.pr" "pr_dylan_wall")"

# Point Robot with Inertia
PRWI_MD=""
PRWI_MD="${PRWI_MD}$(make_graphs "POINT_ROBOT_WITH_INERTIA" "input/pointrobot/dylan/slalom.pr" "prwi_dylan_slalom")"
PRWI_MD="${PRWI_MD}$(make_graphs "POINT_ROBOT_WITH_INERTIA" "input/pointrobot/dylan/unifoom.pr" "prwi_dylan_uniform")"
PRWI_MD="${PRWI_MD}$(make_graphs "POINT_ROBOT_WITH_INERTIA" "input/pointrobot/dylan/cups.pr" "prwi_dylan_cups")"
PRWI_MD="${PRWI_MD}$(make_graphs "POINT_ROBOT_WITH_INERTIA" "input/pointrobot/dylan/wall.pr" "prwi_dylan_wall")"

# Racetrack
RACETRACK_MD=""
RACETRACK_MD="${PRWI_MD}$(make_graphs "RACETRACK" "input/racetrack/barto-big.track" "rt_big")"
RACETRACK_MD="${PRWI_MD}$(make_graphs "RACETRACK" "input/racetrack/barto-small.track" "rt_small")"

# Acrobot
ACROBOT_MD=""
for i in 0.3 0.1 0.09 0.08 0.07; do
  ACROBOT_MD="${ACROBOT_MD}$(make_graphs "ACROBOT" "$duration-$duration" "acrobot_${i}-${i}")"
done

echo "$GRID_WORLD_MD" > $PLOTS_DIR/grid_world_plots.md
echo "$PUZZLE_MD" > $PLOTS_DIR/sliding_tile_puzzle_plots.md
echo "$PR_MD" > $PLOTS_DIR/point_robot_plots.md
echo "$PRWI_MD" > $PLOTS_DIR/point_robot_with_inertia_plots.md
echo "$ACROBOT_MD" > $PLOTS_DIR/acrobot_plots.md

if command -v "pandoc" 2>/dev/null; then
  pandoc -o $PLOTS_DIR/grid_world_plots.pdf $PLOTS_DIR/grid_world_plots.md
  pandoc -o $PLOTS_DIR/sliding_tile_puzzle_plots.pdf $PLOTS_DIR/sliding_tile_puzzle_plots.md
  pandoc -o $PLOTS_DIR/point_robot_plots.pdf $PLOTS_DIR/point_robot_plots.md
  pandoc -o $PLOTS_DIR/point_robot_with_inertia_plots.pdf $PLOTS_DIR/point_robot_with_inertia_plots.md
  pandoc -o $PLOTS_DIR/acrobot_plots.pdf $PLOTS_DIR/acrobot_plots.md
fi