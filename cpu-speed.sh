#!/bin/bash
# show speed of cores
watch -n.1 "grep \"^[c]pu MHz\" /proc/cpuinfo"
