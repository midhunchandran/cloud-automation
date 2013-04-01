#!/bin/bash
#
#This Script will make aws call,parse and provide the server configurations
#
#########################################

#ENV set...
source $HOME/.bashrc

#AWS EC2 call...
echo "Amazon EC2 - checking for instances ..."
ec2-describe-instances | grep INSTANCE | awk {'print $0'} > descInstances.txt

#elb-describe-lbs | grep LOAD_BALANCER |awk {'print $0'} > descElbs.txt

echo "Amazon EC2 - checking for loadbalancers..."
elb-describe-lbs --show-long --delimiter "|" | grep LOAD_BALANCER | awk {'print $0'} > descElbs.txt
echo "Amazon EC2 ... checks completed"
echo "Processing results ..."

cat descInstances.txt | grep INSTANCE |awk {'print $0'} > inputInstances.txt 

cat descElbs.txt | grep LOAD_BALANCER |awk {'print $0'} > inputElbs.txt 


echo "===================== " > aws-config.out
count=1

cat inputElbs.txt | while read LINE
do
  echo "LOAD_BALANCER # $count" >> aws-config.out
  echo "=====================" >> aws-config.out
  echo -n "LOAD_BALANCER_NAME     = " >> aws-config.out
  echo $LINE | grep LOAD_BALANCER | awk -F '|' {'print $2'} >> aws-config.out
  echo -n "LOADBALANCER_DNS       = " >> aws-config.out
  echo $LINE | grep LOAD_BALANCER | awk -F '|' {'print $3'} >> aws-config.out
  echo -n "LOAD_BALANCER_MEMBERS  = " >> aws-config.out
  echo $LINE | grep LOAD_BALANCER | awk -F '|' {'print $10'} >> aws-config.out
  echo "=====================" >> aws-config.out
let count++
done

count=1

cat inputInstances.txt | while read LINE
do
  echo "INSTANCE#= $count" >> aws-config.out
  echo "=====================" >> aws-config.out
  echo -n "INSTANCE_ID         = " >> aws-config.out
  echo $LINE | grep INSTANCE |awk {'print $2'} >> aws-config.out
  echo -n "IMAGE_ID            = " >> aws-config.out
  echo $LINE | grep INSTANCE |awk {'print $3'} >> aws-config.out
  echo -n "INSTANCE_TYPE       = " >> aws-config.out
  echo $LINE | grep INSTANCE |awk {'print $9'} >> aws-config.out
  type=`echo $LINE | grep INSTANCE |awk {'print $9'}`
  grep $type instance-types >> aws-config.out
  echo -n "PUBLIC_DNS          = " >> aws-config.out
  echo $LINE | grep INSTANCE |awk {'print $4'} >> aws-config.out
  echo -n "PRIVATE_DNS         = " >> aws-config.out
  echo $LINE | grep INSTANCE |awk {'print $5'} >> aws-config.out
  echo -n "PUBLIC_IP_ADDR      = " >> aws-config.out
  echo $LINE | grep INSTANCE |awk {'print $14'} >> aws-config.out  
  echo -n "PRIVATE_IP_ADDR     = " >> aws-config.out
  echo $LINE | grep INSTANCE |awk {'print $15'} >> aws-config.out
  echo -n "TYPE_OF_ROOT_DEVICE = " >> aws-config.out
  echo $LINE | grep INSTANCE |awk {'print $18'} >> aws-config.out  
  echo "=====================" >> aws-config.out
let count++
done
  
echo "Scan results stored in aws-config.out"
cat aws-config.out
