IP=`awk -F: -f get_ip.awk mysql.out`
echo "mysql ip = " $IP
echo

echo "Updating chef node with database ip"
ruby chef-api/set_site_and_db -s "demo.cloudmovers.org" -d $IP
