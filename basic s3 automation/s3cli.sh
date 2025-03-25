#!/bin/bash

#variables, change it to what you want
bucket_name="yourbucket9000"
region_code="ap-south-1"
file_name="image.jpg"
file_path="path/to/file/image.jpg"

bucket_config() 
{
while true; do
 cat<<END
 +-------------------+
 | Choose an option: |
 +-------------------+
 | 1) Create Bucket  |
 | 2) Delete Bucket  |
 | 3) List Bucket    |
 | 4) Quit Menu      |
 +-------------------+
END

  read -r -p "Answer Here: " option
 
  case $option in
   1)
    #create bucket
    if aws s3api create-bucket \
     --bucket $bucket_name \
     --region $region_code \
     --create-bucket-configuration LocationConstraint=$region_code; then
     echo "$bucket_name has been successfully created in $region_code!"
    else
     echo Failed to create bucket: $bucket_name in $region_code.
    fi
    ;;

   2)
    #delete bucket
    if aws s3api delete-bucket --bucket $bucket_name; then
     echo $bucket_name has been sucessfully deleted!
    else
     echo Failed to delete bucket: $bucket_name 
    fi
    ;;

   3)
    #list bu1ckets
    aws s3api list-buckets --query "Buckets[].Name"
    ;;

   4)
    #exit menu
    echo goodbye!
    main_menu
    ;;

   *)
    #wrong input
    echo Wrong input, please try again.
    ;;
  esac

done
}

object_config()
{
while true; do
 cat<<END
 +--------------------+
 | Choose an option:  |
 +--------------------+
 | 1) Put Object      |
 | 2) Delete Object   |
 | 3) List Objects    |
 | 4) Quit Menu       |
 +--------------------+
END

 read -r -p "Answer Here: " option
 case $option in
  1)
   #upload object
   if aws s3api put-object \
    --body $file_path \
    --bucket $bucket_name \
    --key  $file_name; then
    echo "Successfully uploaded $file_name to $bucket_name"
   else
    echo "Failed to upload file: $file_name to $bucket_name"
   fi
   ;;
  2)
   #delete object
   if aws s3api delete-object \
    --bucket $bucket_name \
    --key $file_name; then
    echo "Successfully deleted $file_name from $bucket_name"
   else
    echo "Failed to delete file: $file_name from $bucket_name"
   fi
   ;;
  3)
   #list objects
   aws s3api list-objects-v2 \
   --bucket $bucket_name \
   --query "Contents[].Key"
   ;;
  4)
   #exit menu
   echo goodbye!
   main_menu
   ;;
  *)
   echo Wrong input, please try again.
   ;;
 esac
done
}

main_menu()
{
while true; do
 cat <<END
 +--------------------------------+
 | What do you want to configure? |
 +--------------------------------+
 | 1) Buckets                     |
 | 2) Objects                     |
 | 3) Quit Menu                   |
 +--------------------------------+
END

 read -r -p "Answer Here: " option

#bucket menu
case $option in 
 1)
  bucket_config
  ;;
 2)
  object_config
  ;;
 3)
  echo goodbye!
  exit 0
  ;;
 *)
  echo Wrong input, please try again.
  ;;
esac
done
}

main_menu
