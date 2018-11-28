#!/bin/sh

SCRIPT='~/project/NetLogo/netlogo-headless.sh'
LINES_PER_FILE=1

# assert command line arguments valid
if [ "$#" -gt "1" ]
    then
        echo 'usage: ./run.sh [RESULTS_DIR]'
        exit
    fi

# get folder name for results
if [ "$#" == "1" ]
    then
        RESULTS_DIR=$1
    else
        RESULTS_DIR=$(date +%Y-%m-%dT%H:%M:%S%z)
    fi

# amalgamate all tasks
TASKS_PREFIX='tasks_'
rm "$TASKS_PREFIX"*.sh 2>/dev/null
rm tasks.sh 2>/dev/null
for i in `seq 200`; do
for EXPERIMENT in 'squared-difference-main' 'absolute-difference-main' 'other-genome-main' 'baseline-main' 'euclidean-distance-main'; do
    PREFIX="$EXPERIMENT"'-'"$i"
    DIR="$RESULTS_DIR"'/'"$PREFIX"
    mkdir -p $DIR
    cp *.nlogo "$DIR"'/'
    cp *.py "$DIR"'/'
    ARGS=('--model model.nlogo'
          '--experiment '"$EXPERIMENT"
          '--threads 1'
          '--table table-'"$EXPERIMENT"'-'"$i"'.out'
          '--spreadsheet spreadsheet-'"$EXPERIMENT"'-'"$i"'.out')
    echo 'cd '"$DIR"' && '"$SCRIPT"' '"${ARGS[@]}" >> tasks.sh
done
done

# split tasks into files
perl -MList::Util=shuffle -e 'print shuffle(<STDIN>);' < tasks.sh > temp.sh
rm tasks.sh 2>/dev/null
split -l $LINES_PER_FILE -a 3 temp.sh
rm temp.sh
AL=({a..z})
for i in `seq 0 25`; do
    for j in `seq 0 25`; do
        for k in `seq 0 25`; do
        FILE='x'"${AL[i]}${AL[j]}${AL[k]}"
        if [ -f $FILE ]; then
            ID=$((i * 26 * 26 + j * 26 + k))
            ID=${ID##+(0)}
            mv 'x'"${AL[i]}${AL[j]}${AL[k]}" "$TASKS_PREFIX""$ID"'.sh' 2>/dev/null
            chmod +x "$TASKS_PREFIX""$ID"'.sh' 2>/dev/null
        else
            break 3
        fi
        done
    done
done
echo $ID
