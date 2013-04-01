CWD=`pwd`
cd $HOME

echo "Creating node wordpress1 ....."
knife rackspace server create -r 'role[wordpress-nodb]' --server-name wordpress1 --node-name wordpress1 --image 8a3a9f96-b997-46fd-b7a8-a9e740796ffd --flavor 2 > $CWD/wordpress1.out &

sleep 60
echo
echo "Creating node wordpress2 ....."
knife rackspace server create -r 'role[wordpress-nodb]' --server-name wordpress2 --node-name wordpress2 --image 8a3a9f96-b997-46fd-b7a8-a9e740796ffd --flavor 2 > $CWD/wordpress2.out

cd $CWD

echo
echo "------------- wordpress1 details ------------"
tail -11 $CWD/wordpress1.out
echo
echo "------------- wordpress2 details ------------"
tail -11 $CWD/wordpress2.out


#knife rackspace server create -r 'role[wordpress-nodb]' --server-name wordpress1 --node-name wordpress1 --image 7480d067-b60b-424c-bf8b-1a5ea14b4024 --flavor 2 > /home/midhun/projects/wordpress1.out
#knife rackspace server create -r 'role[wordpress-nodb]' --server-name wordpress2 --node-name wordpress2 --image 7480d067-b60b-424c-bf8b-1a5ea14b4024 --flavor 2 > /home/midhun/projects/wordpress2.out
#knife rackspace server create -r 'role[wordpress-nodb]' --server-name wordpress3 --node-name wordpress3 --image 7480d067-b60b-424c-bf8b-1a5ea14b4024 --flavor 2 > /home/midhun/projects/wordpress3.out

