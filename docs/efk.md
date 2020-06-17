# Deploy EFK stack on RPi 4 cluster

This document is about how to deploy Elasticsearch, Fluentd and Kibana (EFK) on the RPi 4 cluster

## Install Elasticsearch

Here is the instruction about how to install Elasticsearch with TLS and Auth enabled.

```bash
ELASTIC_PASSWORD=<YOUR_PASSWORD> bash scripts/elasticsearch-secrets.sh

helm install es elastic/elasticsearch -f chartvalues/elasticsearch-values.yaml
```

## Install Kibana

Here is the instruction about how to install Kibana as UI of Elasticsearch.

```bash
bash scripts/kibana-secret.sh

helm install kibana elastic/kibana -f chartvalues/kibana-values.yaml
```

## Install Fluentbit
