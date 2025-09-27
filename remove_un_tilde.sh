#!/bin/bash

# Find and remove all files ending with .un~
find . -type f -name "*.un~" -exec rm -v {} \;

