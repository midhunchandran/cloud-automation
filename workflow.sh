#1. Create database node
./create_database_node.sh

#2. Update the database IP in the chef wordpress role
./update_db_in_chef_role.sh

#3. Create wordpress nodes
./create_nodes.sh

#4. Create loadbalancer
#5. Add wordpress nodes behind loadbalancer
#6. Point DNS to the new loadbalancer IP
./configure_lb_and_dns.sh
