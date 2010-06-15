#!/bin/sh

ruby src/prbc.rb src/prbc.rb -o bin/prbc
bin/prbc src/main.rb -o bin/pconfigure
bin/prbc src/pclean.rb -o bin/pclean
cp bin/* ../../bin/