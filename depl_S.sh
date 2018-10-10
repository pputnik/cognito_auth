#!/bin/bash

templateurl="--template-url https://s3.amazonaws.com/b-o-l-service/cognito/test_env_devMgmt.yml"
tags="--tags Key=Name,Value=cognito-test$1 Key=project,Value=b-o-l Key=subproject,Value=cognito-test$1"
stackname="--stack-name cognito-test$1"
#capab="--capabilities CAPABILITY_NAMED_IAM"
capab="--capabilities CAPABILITY_IAM"

cd /root/cognito/


echo -n testing 
aws cloudformation validate-template --template-body "file://./test_env_devMgmt.yml" >/dev/null
if [ $? -ne 0 ]; then
        echo " syntax error"
        exit -1
fi

aws s3 cp /root/cognito/ s3://b-o-l-service/cognito/ --recursive --exclude '.git/*' --acl public-read | grep -v amazon-cognito-identity-js
echo -n "checking if exists "
status=$(aws cloudformation describe-stacks $stackname 2>&1| grep 'StackStatus"' | awk -F'"' '{print $4}')
if [ "$status" == "ROLLBACK_FAILED" ] || [ "$status" == "ROLLBACK_COMPLETE" ] || [ "$status" == "CREATE_FAILED" ] || [ "$status" == "DELETE_FAILED" ] ; then
        echo " $status, try to delete"
        aws cloudformation delete-stack $stackname
        x=20
        while [ $x -gt 0 ]; do
                status=$(aws cloudformation describe-stacks $stackname 2>&1 | grep 'StackStatus"' | awk -F'"' '{print $4}')
                echo "$status"
                if [ "x$status" == "x" ]; then
                        x=0
			echo creating....
		        aws cloudformation create-stack $stackname --timeout-in-minutes 210 $templateurl  $tags $capab
                fi
                x=$(($x-1))
                sleep 2
        done
elif [ "$status" == "CREATE_COMPLETE" ] || [ "$status" == "UPDATE_ROLLBACK_COMPLETE" ] || [ "$status" == "UPDATE_COMPLETE" ] || [ "$status" == "UPDATE_ROLLBACK_FAILED" ] ; then
        echo "exist, ($status). Starting update: "
        aws cloudformation update-stack $stackname $templateurl $tags $capab
else
        echo " not exist: $status"

        echo creating ....
        aws cloudformation create-stack $stackname --timeout-in-minutes 210 $templateurl $tags $capab

fi
echo end

