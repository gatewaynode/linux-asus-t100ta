#!/bin/bash

# ASUS T100TA screen autorotation script.
#
# This script automatically rotates the screen by using xrandr after
# checking the accelerometers. The touchscreen and touchpad inputs are
# rotated accordingly by using xinput.

# Copyright 2017 Francesco De Vita <devfra[at]inventati[dot]org>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.  See the License for the specific language governing
# permissions and limitations under the License.


# Time interval in seconds for the accelerometers check.
accel_time_check=3


# Absolute value function.
abs(){
    [ $1 -lt 0 ] && echo $((-$1)) || echo $1
}


# Display usage if wrong input arguments are supplied.
if [[ $# -ne 0 ]]
then
    echo "ASUS T100TA screen autorotation script"
    echo -n "This is a non interactive script, "
    echo "just launch it in background."
    exit 1
fi


# Check if xrandr and xinput are installed.
hash xrandr 2>/dev/null || { echo "xrandr is not installed"; exit 1; }
hash xinput 2>/dev/null || { echo "xinput is not installed"; exit 1; }


# Xrandr output for the screen, supposing no external screen attached.
screen_output=$(xrandr | grep -w connected | cut -d" " -f1)

# IDs of the input devices that have to be rotated.
# The correct input devices are those listed by the command
# "xinput --list" under the "Virtual core pointer" section as in the
# following example:
#
#  ⎡ Virtual core pointer                                id=2
#  ⎜   ↳ Virtual core XTEST pointer                      id=4
#  ⎜   ↳ ASUSTek COMPUTER INC. ASUS Base Station(T100)   id=10
#  ⎜   ↳ ASUSTek COMPUTER INC. ASUS Base Station(T100)   id=11  <--
#  ⎜   ↳ ATML1000:00 03EB:8C0E                           id=12  <--
#
# Note that the "ASUS Base Station" entry appears two times but only
# the last one is required.
input_devices=$(xinput --list | grep ATML1000 | \
                    sed 's/.*id=\([0-9]*\).*/\1/'; \
                xinput --list | grep SIS | \
                    sed 's/.*id=\([0-9]*\).*/\1/'; \
                xinput --list | grep "ASUS.*Base.*pointer" | \
                    tail -1 | sed 's/.*id=\([0-9]*\).*/\1/')


# Check the accelerometers and adjust screen and inputs.
while true
do
    current_rotation=$(xrandr -q --verbose | grep $screen_output | \
                           cut -d" " -f6)
    new_rotation="normal"

    accel_x=$(cat /sys/bus/iio/devices/iio\:device0/in_accel_x_raw)
    accel_y=$(cat /sys/bus/iio/devices/iio\:device0/in_accel_y_raw)

    if [[ $accel_y -gt $(abs $accel_x) ]]
    then
        new_rotation="normal"
        coord_transf_matrix="1 0 0 0 1 0 0 0 1"
    elif [[ $accel_x -gt $(abs $accel_y) ]]
    then
        new_rotation="left"
        coord_transf_matrix="0 -1 1 1 0 0 0 0 1"
    elif [[ $accel_y -lt 0 ]] && [[ $(abs $accel_y) -gt $accel_x ]]
    then
        new_rotation="inverted"
        coord_transf_matrix="-1 0 1 0 -1 1 0 0 1"
    else
         new_rotation="right"
         coord_transf_matrix="0 1 0 -1 0 1 0 0 1"
    fi

    if [[ $new_rotation != $current_rotation ]]
    then
        xrandr --output $screen_output --rotate $new_rotation
        for input in ${input_devices[@]}
        do
            xinput set-prop $input 'Coordinate Transformation Matrix' \
                   $coord_transf_matrix
        done
    fi

    sleep $accel_time_check
done
