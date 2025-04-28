# 
This dir is used to deploying zookeeper cluster on utah m510 cluster.
To use it, 
- (1) run upload_zookeeper.sh to upload zookeeper to /opt/zookeeper_scripts
- Optional: run iterate_node_setup_env.sh to setup the env
- (2) run iterate_zookeeper.sh to setup the conf file
- (3) run restart_zookeeper.sh to restart zookeeper