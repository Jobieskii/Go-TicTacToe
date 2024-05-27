#!/bin/sh

sed -i "s/localhost:8080/$IP/g" js/script.js

exec $@
