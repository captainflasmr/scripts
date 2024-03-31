#! /bin/bash
# $1 = Dir
# Your master key is:
#    b3a74018-5fb897d4-166b76e0-a644a66b-
#    6bd4bf7c-51ff575e-f643b889-c4f47b65

# Initialise
# gocryptfs -init $1

# Mount
gocryptfs $1 $HOME/Documents/mStuff

#fusermount -u $1
