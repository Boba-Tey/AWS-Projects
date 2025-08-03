import boto3
import secrets

dynamo_db = boto3.resource("dynamodb")
table = dynamo_db.Table("OrderList")

sandwich_images = {
    "Grill Cheese Sandwich": "cheese.jpg",
    "Breakfast Sandwich": "breakfast.jpg",
    "Vegetable Sandwich": "veggie.jpg"
}

def place_order(sandwich, image_url):
    order_id = secrets.token_hex(5)
    table.put_item (
        Item = {
            "OrderID": order_id,
            "Sandwich": sandwich,
            "Image": image_url
        }
    )
    return order_id

def my_order(order_id):
    response = table.get_item(
        Key = {"OrderID": order_id}
    )
    item = response.get("Item")
    if item:
        return item["Sandwich"], item["Image"]
    else:
        return None, None


def lex_response(name, message = None, image_url = None):
    response = {
        "sessionState": {
            "dialogAction": {"type": "Close"},
            "intent": {
                "name": name,
                "state": "Fulfilled"
            }
        },
        "messages": []
    }

    if image_url:
        response["messages"].append ({
            "contentType": "ImageResponseCard",
            "imageResponseCard": {
                "title": "Order Progress:",
                "subtitle": message,
                "imageUrl": image_url,
                "buttons": []
            }
        })    
    else:
        response["messages"].append ({
            "contentType": "PlainText",
            "content": message
        })

    return response

def lambda_handler(event, context):
    intent_name = event["sessionState"]["intent"]["name"]
    slots = event["sessionState"]["intent"]["slots"]

    if intent_name == "Ordering":
        sandwich = slots["sandwich"]["value"]["interpretedValue"]
        image_file = sandwich_images.get(sandwich)

        if not image_file:
            return lex_response("Sorry, we don't have an image for that sandwich.", "Ordering")

        image_url = f"https://sandwitch-bot-images.s3.amazonaws.com/{image_file}"
        order_id = place_order(sandwich, image_url)

        return lex_response(
            "Ordering", f"Your order for one {sandwich} has been placed.\nYour Order ID is {order_id}."
        )

    elif intent_name == "Tracking":
        order_id = slots["yourid"]["value"]["interpretedValue"]
        sandwich, image_url = my_order(order_id)

        if image_url:
            return lex_response("Tracking", f"Your order of one {sandwich} is being sliced and packed",  
                image_url = image_url,)
        else:
            return lex_response("Tracking", "I couldn't find an order with that ID. Please try again.")

    else:
        return lex_response("Tracking", "Sorry, I didn't understand that request.")