#!/usr/bin/env bash
encryptionkey=$(docker run --rm busybox:1.31.1 /bin/sh -c "< /dev/urandom tr -dc _A-Za-z0-9 | head -c50") && \
    kubectl create secret generic kibana --from-literal=encryptionkey=$encryptionkey