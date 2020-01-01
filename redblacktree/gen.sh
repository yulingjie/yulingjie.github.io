#!/bin/bash

for filename in ./*.gv; do
    dot -T png "$filename" -o "$(basename "$filename" .gv).png"
done

