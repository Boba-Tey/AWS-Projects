# 📸 Static webhosting, URL generation, content moderation using S3, Lambda & AWS Rekognition

### Goal of this project:
- Host a static website on S3 and allow users to upload their images
- Prevent inappropriate images from being processed using AWS Rekognition
- Send and receive API requests along with renaming the images using Lambda
- Save the processed images in another S3 and return their public URL

#
### The Contents:
- Head to the website hosted on S3 and click Browse
- Once you choose an image, click Upload File
- Rekognition will analyze the image
- If the image passes the check, Lambda will rename it (to avoid any naming conflicts)
- Lambda’s logic was written in python.
- You will then receive a text stating  Your Public URL is Ready
- Click the text to receive your image’s public URL (the image will be saved in another S3 bucket)

![first](https://github.com/user-attachments/assets/cb61b76e-fa76-4d28-98d9-36fd9e230447)

- However if Rekognition detects any illicit material, an error image will occur and the image won’t be uploaded.

![second](https://github.com/user-attachments/assets/a9589892-43ce-4292-81d2-2b669a1e0564)

#
### Project’s Architecture:

<img width="500" src="https://github.com/user-attachments/assets/3fffdb72-313b-4cc9-a488-53a47b8fb9e1" />
