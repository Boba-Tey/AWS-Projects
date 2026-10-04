import json, os, smtplib, secrets, boto3, requests, psycopg
from datetime import date, datetime, timezone, timedelta
from email.message import EmailMessage

# ----------------------
# | Generating Content |
# ----------------------
def get_facts():
    url = "https://api.groq.com/openai/v1/chat/completions"
    headers = { "Authorization": f"Bearer {os.environ["APIKEY"]}" }

    payload = { 
        "messages": [{ "role": "user", "content": "Give an interesting astronomy fact (no special characters and make it long)" }],
        "model": "openai/gpt-oss-120b",
        "temperature": 1,
        "max_completion_tokens": 2048,
        "top_p": 1,
        "stream": False,
        "reasoning_effort": "medium",
        "stop": None
    }

    response = requests.post(url, headers = headers, json = payload)

    if response.status_code == 200:
        data = response.json()
        return data["choices"][0]["message"]["content"]

    else:
        print(f"Couldn't generate content: {response.text}")
        return None

# ------------------
# | Sending Emails |
# ------------------
def send_email(email_id, subject, content):
    message = EmailMessage()
    message.set_content(content)
    message["Subject"] = subject
    message["From"] = os.environ["SENDER"]
    message["To"] = email_id
    
    with smtplib.SMTP("smtp.gmail.com", 587) as smtp:
        smtp.starttls()
        smtp.login(os.environ["SENDER"], os.environ["PASSWORD"])
        smtp.send_message(message, to_addrs = [email_id])

# ------------------
# | Lambda Handler |
# ------------------
def lambda_handler(event, context):
    # -------------
    # | Variables |
    # -------------
    client = boto3.client("dsql")

    db_token = client.generate_db_connect_admin_auth_token(os.environ["DSQLENDPOINT"], Region = None, ExpiresIn = 900)
    db_params = { "host": os.environ["DSQLENDPOINT"], "dbname": "postgres", "user": "admin", "password": db_token, "sslmode": "require" }

    headers = {
        "Access-Control-Allow-Origin": os.environ["WEBSITEURL"],
        "Access-Control-Allow-Methods": "OPTIONS,POST,DELETE",
        "Access-Control-Allow-Headers": "Content-Type"
    }

    bad_outcome = { 
        "statusCode": 302,
        "headers": { "Location": f"{os.environ["WEBSITEURL"]}/error.html" },
        "body": ""
    }

    try:
        endpoint = event.get("path")
        query = event.get("queryStringParameters") or {}

        # ----------------------------
        # | Cleanup Unverified Users |
        # ----------------------------
        if event.get("clean_up"):
            with psycopg.connect(**db_params) as conn:
                result = conn.execute("DELETE FROM astronomy_subscribers WHERE verified = %s", (False,))

                if result.rowcount == 0:
                    print("No unverified users were found")
                    return { "Summary": "No unverified users were found" }

                print(f"{result.rowcount} unverified user/s were removed")
                return { "Summary": f"{result.rowcount} unverified user/s were removed" }

        # -----------------------------------
        # | Sending Funfacts To Subscribers |
        # -----------------------------------
        if event.get("send_news"):
            with psycopg.connect(**db_params) as conn:
                rows = conn.execute("SELECT email, token FROM astronomy_subscribers WHERE verified = %s", (True,)).fetchall()

            if not rows:
                print("No Subscribers Found")
                return { "Output": "No Subscribers Found" }

            news = get_facts()
            
            if not news:
                print("Unable To Send News, No Content Was Provided")
                return { "Output": "Unable To Send News, No Content Was Provided" }

            for row in rows:
                send_email(row[0], f"Astronomy Funfact! ({date.today()})", 
                    f"{news}\n\nIf you wish to stop receiving our emails, unsubscribe here:\n{os.environ['APIBASEURL']}/unsubscribe?token={row[1]}")

            print("Newsletter Sent")
            return { "Output": "Newsletter Sent" }

        # --------------------
        # | Registering User |
        # --------------------
        elif endpoint == "/register":
            data = json.loads(event.get("body")) if event.get("body") else None
            email_id = data.get("create_email")
            token = secrets.token_hex(16)

            if not email_id:
                return {
                    "statusCode": 400,
                    "headers": headers,
                    "body": json.dumps({ "outcome": "Email is required" })
                }

            with psycopg.connect(**db_params) as conn:
                row = conn.execute("SELECT expires_at, verified FROM astronomy_subscribers WHERE email = %s", (email_id,)).fetchone()
                
                if not row:
                    conn.execute("INSERT INTO astronomy_subscribers (email, token, expires_at) VALUES (%s, %s, %s)", 
                        (email_id, token, datetime.now(timezone.utc) + timedelta(minutes = 10)))
        
                elif row[1]:
                    return { 
                        "statusCode": 400, 
                        "headers": headers,
                        "body": json.dumps({ "outcome": "Email is already subscribed to our Newsletter" })
                    }
        
                elif datetime.now(timezone.utc) > row[0]:
                    token = secrets.token_hex(16)

                    conn.execute("UPDATE astronomy_subscribers SET token = %s, expires_at = %s  WHERE email = %s", 
                        (token, datetime.now(timezone.utc) + timedelta(minutes = 10), email_id))
        
                else:
                    return { 
                        "statusCode": 400, 
                        "headers": headers,
                        "body": json.dumps({ "outcome": "Max numbers of retry exceeded, please try again later" })
                    }

            confirmation = "Thank you for your interest in our Astronomy Newsletter. To confirm your registration, please click the link below:\n"
            link = f"{os.environ['APIBASEURL']}/verify?token={token}\nDO NOT share the link with anyone, this link expires in 10 minutes."
            send_email(email_id, "Registration Confirmation", confirmation + link)

            return {
                "statusCode": 200, 
                "headers": headers,
                "body": json.dumps({ "email": email_id })
            }

        # -------------------      
        # | Confirming User |
        # -------------------  
        elif endpoint == "/verify":
            if not query.get("token"):
                bad_outcome["headers"]["Location"] = f"{os.environ['WEBSITEURL']}/error.html?noemail=true"
                return bad_outcome
    
            with psycopg.connect(**db_params) as conn:
                row = conn.execute("SELECT expires_at FROM astronomy_subscribers WHERE token = %s", (query.get("token"),)).fetchone()

                if not row:
                    bad_outcome["headers"]["Location"] = f"{os.environ['WEBSITEURL']}/error.html?noemail=true"
                    return bad_outcome

                elif datetime.now(timezone.utc) > row[0]:
                    bad_outcome["headers"]["Location"] = f"{os.environ['WEBSITEURL']}/error.html?expired=true"
                    return bad_outcome

                new_token = secrets.token_hex(16)

                conn.execute("UPDATE astronomy_subscribers SET token = %s, expires_at = %s, verified = %s WHERE token = %s", 
                    (new_token, None, True, query.get("token")))
                 
            return {
                "statusCode": 302,
                "headers": { "Location": f"{os.environ['WEBSITEURL']}/confirm.html?verified=true" },
                "body": ""
            }
        
        # ------------------
        # | Deleting Email |
        # ------------------
        elif endpoint == "/unsubscribe":
            if not query.get("token"):
                bad_outcome["headers"]["Location"] = f"{os.environ['WEBSITEURL']}/error.html?noemail=true"
                return bad_outcome
            
            with psycopg.connect(**db_params) as conn:
                result = conn.execute("DELETE FROM astronomy_subscribers WHERE token = %s", (query.get("token"),))

                if result.rowcount == 0:
                    bad_outcome["headers"]["Location"] = f"{os.environ['WEBSITEURL']}/error.html?noemail=true"
                    return bad_outcome

            return {
                "statusCode": 302,
                "headers": { "Location": f"{os.environ['WEBSITEURL']}/cancel.html" },
                "body": ""
            }

        # -------------------
        # | Invalid Request |
        # -------------------
        else:
            bad_outcome["headers"]["Location"] = f"{os.environ['WEBSITEURL']}/error.html?nopath=true"
            return bad_outcome
        
    except Exception as e:
        print(e)
        return bad_outcome