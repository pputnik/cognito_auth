#!/bin/bash

cd /root/cognito/

template="--template-body file://test_env_devMgmt.yml"
#s3://cognito-test-alex
params="--parameters file://cognito-configuration-CC.json"
tags="--tags Key=Name,Value=cognito-test"
stackname="--stack-name cognito-test"
#capab="--capabilities CAPABILITY_NAMED_IAM"
capab="--capabilities CAPABILITY_IAM"

if [ "x$1" = "x" ] ; then
    echo commit comment required
    exit -1
fi



echo -n testing 
aws cloudformation validate-template --template-body "file://test_env_devMgmt.yml" >/dev/null
if [ $? -ne 0 ]; then
        echo " syntax error"
        exit -1
fi

git add *
git status
git commit -m "$1"
git push

#aws s3 cp /root/cognito/ s3://b-o-l-service/cognito/ --recursive --exclude '.git/*' --acl public-read | grep -v amazon-cognito-identity-js
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
		        aws cloudformation create-stack $stackname --timeout-in-minutes 210 $template  $tags $capab $params
                fi
                x=$(($x-1))
                sleep 2
        done
elif [ "$status" == "CREATE_COMPLETE" ] || [ "$status" == "UPDATE_ROLLBACK_COMPLETE" ] || [ "$status" == "UPDATE_COMPLETE" ] || [ "$status" == "UPDATE_ROLLBACK_FAILED" ] ; then
        echo "exist, ($status). Starting update: "
        aws cloudformation update-stack $stackname $template $tags $capab $params
else
        echo " not exist: $status"

        echo creating ....
        aws cloudformation create-stack $stackname --timeout-in-minutes 210 $template $tags $capab $params

fi
echo end

