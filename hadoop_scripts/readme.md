### Hadoop Cluster Deployment
- (1) run `upload_hadoop.sh` to upload hadoop to `/opt/hadoop_scripts`
- (2) run `iterate_node_reconfigure.sh` to unzip and reconfigure the conf file
- (3) run `iterate_restart_hadoop.sh` to restart hadoop

iterate_restart_hadoop.sh please execute manually in each node for once, otherwise there is ssh issue。

### Change Cluster Parameter
- (1) Change upload_hadoop.sh parameter
- (2) Change iterate_node_reconfigure.sh parameter

Please note topology.sh should be given sudo chmox +x on all nodes