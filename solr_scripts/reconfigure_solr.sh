#!/bin/bash

echo "Starting Solr extraction and setup..."
sudo rm -rf /opt/SolrData
sudo mkdir -p /opt/SolrData
sudo rm -rf /opt/SolrDataPilot
sudo mkdir -p /opt/SolrDataPilot
sudo rm -rf /opt/ShadowDirectory
sudo rm -rf /opt/ShadowAppendLog
sudo chmod -R 777 /opt
sudo chmod +x /opt/Solr/solr/bin/solr

cp /opt/Solr/solr/server/solr/solr.xml /opt/SolrData/