#!/bin/sh

sed -i "s/localhost:8080/$IP/g" js/script.js
sed -i "s|%DOMAIN%|$DOMAIN|g" index.html 
sed -i "s/%CLIENT%/$CLIENTID/g" index.html

$@
