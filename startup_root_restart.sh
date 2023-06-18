#!/bin/bash

killall ydotoold

ydotoold --socket-perm 0777 --socket-path=/run/user/1000/.ydotool_socket &
