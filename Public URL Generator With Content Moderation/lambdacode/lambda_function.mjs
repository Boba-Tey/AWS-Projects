import { RekognitionClient, DetectModerationLabelsCommand } from "@aws-sdk/client-rekognition";
import { DynamoDBClient, GetItemCommand, UpdateItemCommand } from "@aws-sdk/client-dynamodb";
import { S3Client, PutObjectCommand, CopyObjectCommand, DeleteObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

export const handler = async (event) => {
    const explicit_list = [
        "Explicit Nudity", 
        "Explicit Sexual Activity",
        "Graphic Violence",
        "Death and Emaciation",
        "Hate Symbols"
    ];

    const headers = { "Access-Control-Allow-Origin": process.env.WEBSITEURL };

    try {
        const s3_client = new S3Client();
        const db_client = new DynamoDBClient();

        // Update Item
        async function update_item(image, status, value) {
            const ttl_in_seconds = Math.floor(Date.now() / 1000) + (10 * 60);

            const command = new UpdateItemCommand({
                TableName: process.env.DBNAME,
                Key: { image_name: { S: image } },

                UpdateExpression: "SET #status_name = :status_value, expires_at = :ttl_value",
                ExpressionAttributeNames: { "#status_name": "status" },

                ExpressionAttributeValues: { 
                    ":status_value": { M: { [status]: { S: value } } },
                    ":ttl_value": { N: ttl_in_seconds.toString() } 
                }
            });

            await db_client.send(command);
        }

        // Image Status
        if (event.path === "/image_status") {
            const image = event.queryStringParameters?.image_name;

            if (!image) {
                return { 
                    statusCode: 400, 
                    headers: headers, 
                    body: JSON.stringify({ error: "No image name provided" })
                }; 
            }

            const command = new GetItemCommand({
                TableName: process.env.DBNAME,
                Key: { image_name: { S: image } },
            });

            const response = await db_client.send(command);
            const status = Object.keys(response.Item.status.M)[0];
            const result = { [status]: response.Item.status.M[status].S };

            return { 
                statusCode: 200, 
                headers: headers, 
                body: JSON.stringify(result)
            };

        // Image Upload
        } else if (event.path === "/image_upload") {
            const body = JSON.parse(event.body);
            const image = `${crypto.randomUUID()}.${body.file_extension}`;
            
            const put_command = new PutObjectCommand({
                Bucket: process.env.BUCKETNAME,
                Key: `unverified/${image}`
            });

            const presigned = await getSignedUrl(s3_client, put_command);
            await update_item(image, "pending", "Verification incomplete");

            return { 
                statusCode: 200, 
                headers: headers, 
                body: JSON.stringify({ 
                    presigned_url: presigned, 
                    image_name: image
                })
            };

        // Verifying Image
        } else if (event.Records?.[0]?.eventSource === "aws:s3") {
            const image_name = event.Records[0].s3.object.key.split("/").pop();
            const new_file = `public/${image_name}`;

            const rekog_client = new RekognitionClient();

            const delete_command = new DeleteObjectCommand({ 
                Bucket: process.env.BUCKETNAME,
                Key: event.Records[0].s3.object.key
            });

            // Max Filesize Exceeded
            if (event.Records[0].s3.object.size > 2 * 1024 * 1024) {
                await s3_client.send(delete_command);

                await update_item(
                    image_name, "failed", 
                    "File exceeded max limit of 2 MB, please upload another image."
                );

                console.log("File Exceeded Max Limit Of 2 MB");
                return 
            }

            // RUnning AWS Rekognition
            try {
                const moderate_command = new DetectModerationLabelsCommand({
                    Image: { S3Object: 
                        { "Bucket": process.env.BUCKETNAME, "Name": event.Records[0].s3.object.key } 

                    }, MinConfidence: 60,
                });

                const response = await rekog_client.send(moderate_command);

                // Inappropriate Content Found
                if (response.ModerationLabels.length > 0) {
                    for (const label of response.ModerationLabels) { 
                        if (explicit_list.includes(label.Name)) {
                            await s3_client.send(delete_command);

                            await update_item(
                                image_name, "failed", 
                                "Inappropriate material detected, please upload another image."
                            );

                            console.log(`inappropriate material detected: ${label.Name}`);
                            return
                        }
                    };
                }

            } catch (err) {
                if (err.name === "InvalidImageFormatException") {
                    await s3_client.send(delete_command);

                    await update_item(
                        image_name, "failed", 
                        "Wrong Image format, please upload only JPG or PNG Images"
                    );

                    console.log("Wrong Image format");
                    return;
                }

                else console.error(err);
            }

            // Image Verified And Copied To Public Prefix
            const copy_command = new CopyObjectCommand({
                Bucket: process.env.BUCKETNAME,
                CopySource: encodeURIComponent(`${process.env.BUCKETNAME}/${event.Records[0].s3.object.key}`),
                Key: new_file
            });

            await s3_client.send(copy_command);
            await s3_client.send(delete_command);

            await update_item(image_name, "verified", `${process.env.VERIFYINGURL}/${new_file}`);
            console.log(`Image is verified, URL: ${process.env.VERIFYINGURL}/${new_file}`);

        // Wrong Path
        } else {
            console.log("Invalid event");

            return { 
                statusCode: 400, 
                headers: headers,
                body: JSON.stringify({ error: "Unsupported Event" })
            };
        }

    } catch(err) {
        console.error(err);

        return {
            statusCode: 500,
            headers: headers,
            body: JSON.stringify({ error: "Internal Server Error" })
        };
    }
};