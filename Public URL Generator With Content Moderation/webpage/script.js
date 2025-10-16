const img_url = document.getElementById("img_link");
const img_para = document.getElementById("img_para");

function select_img() {
    const avatar = document.getElementById("avatar");
    avatar.click();
}

document.getElementById("avatar").addEventListener("change", function () {
    const file = this.files[0];
    const preview = document.getElementById("img_preview");

    if (file) {
        preview.src = URL.createObjectURL(file);
        img_url.href = "";
        img_url.textContent = "";
        if (img_para) img_para.textContent = "";
    }
});

const LAMBDA_URL = "${lambda_url}";

async function upload_img() {
    const file = document.getElementById("avatar").files[0];
    if (!file) {
        alert("No file selected!");
        return;
    }

    const reader = new FileReader();
    reader.onload = async function () {
        const base64Image = reader.result.split(',')[1];

        try {
            const response = await fetch(LAMBDA_URL, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json"
                },
                body: JSON.stringify({
                    filename: file.name,
                    content_type: file.type,
                    imageBase64: base64Image
                })
            });

            const result = await response.json();

            if (!response.ok) {
                const error_message = result.message || "Unknown error";
                const moderation_labels = result.moderation_labels || [];
                if (img_para) img_para.textContent = error_message;
                console.error("Upload failed:", response.status, error_message, moderation_labels);
                return;
            }

            if (result.url) {
                if (img_url) {
                    img_url.href = result.url;
                    img_url.textContent = "Your Public URL is ready!";
                }
                if (img_para) img_para.textContent = "";
                console.log("Your Image URL:", result.url);
            }

        } catch (error) {
            console.error("Fetch error:", error);
        }
    };

    reader.readAsDataURL(file);
}
