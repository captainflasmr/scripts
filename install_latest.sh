#!/bin/bash

grep 'installed' /var/log/pacman.log | tail -n 50
