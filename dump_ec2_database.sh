ssh -i ~/.ssh/aws-keypair.pem ubuntu@hostname 'mysqldump -u user -p databasename' > xdb.sql
