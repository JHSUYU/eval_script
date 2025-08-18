(1)run upload.sh
(2)run iterate_node.sh
(3)Everytime change the code, run upload.sh again, and follow iterate_node_env.sh

./solr start -c -z 10.10.1.1:2181,10.10.1.2:2181,10.10.1.3:2181 -p 8983 -h 10.10.1.2 -s /opt/SolrData -m 8g