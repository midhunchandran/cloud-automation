CWD=`pwd`
cd $HOME 
knife rackspace server create -r 'role[database]' --server-name mysql --node-name mysql --image 8a3a9f96-b997-46fd-b7a8-a9e740796ffd --flavor 2 > $CWD/mysql.out
cd $CWD
