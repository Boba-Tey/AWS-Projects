import boto3
from prettytable import PrettyTable
from art import *

def s3_menu():
 s3 = boto3.client("s3")
 tprint("S3 Python",font="small")

 def bucket_config():
  print()
  while True:
   print("+----------------------------+"
       "\n| What would you like to do? |"
       "\n+----------------------------+"
       "\n| 1) Create Bucket           |"
       "\n| 2) Delete Bucket           |"
       "\n| 3) List Buckets            |"
       "\n| 4) Quit Menu               |"
       "\n+-------------------------=--+")
   start= input("Answer Here: ")

   if start=="1":
    try:
     print()
     print("+-------------------------+"
         "\n| Bucket Name (Q to quit) |"
         "\n+-------------------------+")
     bucket_name=input("Enter Here: ")
     if bucket_name.lower() == "q":
      bucket_config()
      break
     print()
     print("+-------------------------+"
         "\n| Region Code (Q to quit) |"
         "\n+-------------------------+")
     region_code=input("Enter Here : ")
     if region_code.lower() == "q":
      bucket_config()
      break
      
     s3.create_bucket(Bucket= bucket_name, CreateBucketConfiguration={
     "LocationConstraint": region_code})
     print(f"{bucket_name} has been created in {region_code}!")
     print()
    except Exception as e:
     print(f"Error: {e}")
     print()

   elif start=="2":
    try:
     print()
     print("+------------------------------+"
         "\n| Bucket To Delete (Q to quit) |"
         "\n+------------------------------+")
     bucket_delete=input("Enter Here: ")
     if bucket_delete=="Q" or bucket_delete=="q":
      bucket_config()
     
     list= s3.list_buckets()
     bucket_exists = any(bucket["Name"] == bucket_delete for bucket in list['Buckets'])
     if not bucket_exists:
      raise Exception(f"Bucket '{bucket_delete}' does not exist in your account.")
     else:
      s3.delete_bucket(Bucket= bucket_delete)
      print(f"{bucket_delete} has been deleted!")
      print()

    except Exception as e:
     print(f"Error: {e}")
     bucket_config()

   elif start=="3":
    print()
    list= s3.list_buckets()
    if list["Buckets"]:
     table = PrettyTable()
     table.field_names = ["Your Buckets:"]
     table.align = "l"
     for bucket in list["Buckets"]:
      table.add_row([bucket["Name"]])
     print(table)
     print()
    else:
     print("+-----------------------------------+"
         "\n| No Buckets found in this account. |"
         "\n+-----------------------------------+")
     bucket_config()
     break

   elif start=="4": 
    print()
    break
   
   else:
    print()
    print("+-------------------------------+"
        "\n| Wrong input please try again! |"
        "\n+-------------------------------+")
    print()
   
 def object_config():
  print()
  while True:
   print("+-------------------------+"
       "\n| Bucket Name (Q to quit) |"
       "\n+-------------------------+")
   bucket_name=input("Enter Here: ")
   if bucket_name.lower()=="q":
    s3_menu()

   try:
    list= s3.list_buckets()
    bucket_exists = any(bucket["Name"] == bucket_name for bucket in list['Buckets'])
    if not bucket_exists:
     raise Exception(f"Bucket '{bucket_name}' does not exist in your account.")
    
    else:
     print()
     while True: 
      print("+----------------------------+"
          "\n| What would you like to do? |"
          "\n+----------------------------+"
          "\n| 1) Upload Object           |"
          "\n| 2) Delete Object           |"
          "\n| 3) List Objects            |"
          "\n| 4) Quit Menu               |"
          "\n+----------------------------+")
      start=input("Answer Here: ")

      if start=="1":
       print()
       print("+------------------------------------------------+"
           "\n| Name your file with it's extension (Q to quit) |"
           "\n+------------------------------------------------+")
       object_name=input("Enter Here (Q to quit): ")
       if object_name.lower() == "q":
        object_config()

       print()
       print("+-------------------------------+"
           "\n| Path to your file (Q to quit) |"
           "\n+-------------------------------+")
       path_name=input("Enter Here (Q to quit): ")
       if path_name.lower() == "q":
        object_config()
       
       try:
        s3.upload_file(path_name, bucket_name, object_name)
        print(f"{object_name} has been uploaded to {bucket_name}!")
        print()
       except Exception as e:
        print(f"Error: {e}")
        print()

      elif start=="2":
       print()
       print("+---------------------------------------+"
           "\n| Object to delete (with the extension) |"
           "\n+---------------------------------------+")
       object_name=input("Enter Here (Q to quit): ")
       if object_name.lower() == "q":
        object_config()
       
       try:
        object_list= s3.list_objects_v2(Bucket= bucket_name)
        object_exists = any(object["Key"] == object_name for object in object_list.get("Contents", []))
        if not object_exists:
         raise Exception(f"Object '{object_name}' does not exist in your bucket.")
        else:
         s3.delete_object(Bucket= bucket_name, Key= object_name)
         print(f"{object_name} has been deleted from {bucket_name}!")
         print()

       except Exception as e:
        print(f"Error: {e}")
        print()

      elif start=="3":
       print()
       bucket_list= s3.list_objects_v2(Bucket= bucket_name)
       if "Contents" in bucket_list:
        table = PrettyTable()
        table.field_names = ["Your Objects:"]
        table.align = "l"
        for object in bucket_list["Contents"]:
         table.add_row([object["Key"]])
        print(table)
        print()
       else:
        print("+----------------------------------+"
            "\n| No objects found in this bucket. |"
            "\n+----------------------------------+")
        print()

      elif start=="4":
       object_config()

      else:
       print()
       print("+-------------------------------+"
           "\n| Wrong input please try again! |"
           "\n+-------------------------------+")
       print()
  
   except Exception as e:
      print(f"Error: {e}")
      print()
 
 while True:
  print("+---------------------------------+"
      "\n| What do you want to configure?  |"
      "\n+---------------------------------+"
      "\n| 1) Buckets                      |"
      "\n| 2) Objects                      |"
      "\n| 3) Quit Menu                    |"
      "\n+---------------------------------+")
  main_menu= input("Answer Here: ")

  if main_menu=="1":
   bucket_config()
  elif main_menu=="2":
   object_config()
  elif main_menu=="3":
   exit()
  else:
   print()
   print("+-------------------------------+"
       "\n| Wrong input please try again! |"
       "\n+-------------------------------+")
   print()


s3_menu()