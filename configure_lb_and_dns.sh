IP1=`awk -F: -f get_ip.awk wordpress1.out`
echo "wordpress1 ip = " $IP1

IP2=`awk -F: -f get_ip.awk wordpress2.out`
echo "wordpress2 ip = " $IP2
echo

echo "Creating loadbalancer with wordpress1 node"
lb_create_resp=`loadbalancer/create_loadbalancer.pl -a $RACKSPACE_ACCOUNT_NUMBER -n $IP1 -p 80`

lb_id=`echo $lb_create_resp | awk -F: '/Load Balancer Id:/ { id=$2 } END {print id} '`
echo "Load balancer ID = " $lb_id

lb_ip=`echo $lb_create_resp | awk -F: '/IP:/ { ip=$4 } END {print ip}'`
echo "Load balancer IP = " $lb_ip
echo

echo "Waiting for loadbalancer to be ready ....."
status="BUILD"
while [ "$status" != "ACTIVE" ]
do
status=`loadbalancer/check_lb_status.pl -a $RACKSPACE_ACCOUNT_NUMBER -l $lb_id`
echo "Loadbalancer status: $status"
sleep 10
done

echo "Adding wordpress2 to the loadbalancer"
loadbalancer/loadbalancer_addnodes.pl -a $RACKSPACE_ACCOUNT_NUMBER -l $lb_id -n $IP2 -p 80

echo "Updating DNS for demo.cloudmovers.org"
dns/update_dns.pl -a $RACKSPACE_ACCOUNT_NUMBER -p $lb_ip

