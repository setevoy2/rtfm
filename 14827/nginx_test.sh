#!/usr/bin/env bash

docker run -ti -v $(pwd):/etc/nginx/conf.d \
    -v $(pwd)/tests/nginx.conf:/etc/nginx/nginx.conf \
    -v $(pwd)/tests/mime.types:/etc/nginx/mime.types \
    -v $(pwd)/tests/letsencrypt/:/etc/letsencrypt/ \
    -v $(pwd)/tests/nginx_ssl/ssl:/etc/nginx/ssl \
    nginx nginx -t

if [ $? == 0 ]; then 
    echo -e "\nOK: NGINX test passed."
else 
    echo -e "\nERROR: NGINX configs test failed. Exit."
    exit 1
fi
