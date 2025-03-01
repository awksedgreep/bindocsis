#!/usr/bin/env zsh
for file in `ls test/fixtures/*.cm`                                                                                          ✔  took 1m 9s  at 06:22:13 PM 
do
  echo $file; bin/bindocsispp.exs -f $file
done
