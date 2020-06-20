# Deploy EFK stack on RPi 4 cluster

This document is about how to deploy Elasticsearch, Fluentd and Kibana (EFK) on the RPi 4 cluster

## Install Elasticsearch

Here is the instruction about how to install Elasticsearch with TLS and Auth enabled.

```bash
ELASTIC_PASSWORD=<YOUR_PASSWORD> bash scripts/elasticsearch-secrets.sh

helm install es elastic/elasticsearch -f chartvalues/efk/elasticsearch-values.yaml
```

## Install Kibana

Here is the instruction about how to install Kibana as UI of Elasticsearch.

```bash
bash scripts/kibana-secret.sh

helm install kibana elastic/kibana -f chartvalues/efk/kibana-values.yaml
```

## Install Fluentbit

Here is the instruction about how to install Fluentbit as log collector.

```bash
helm install fb stable/fluent-bit -f chartvalues/efk/fluentbit-values.yaml
```

## Install Curator

In order to make sure the logs won't exceeds the storage, we use Elastic Curator to cleanup the logs.

```bash
helm install curator stable/elasticsearch-curator -f chartvalues/efk/curator-cv.yaml
```
