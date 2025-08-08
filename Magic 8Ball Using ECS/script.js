const responses = [
    ["yes", "absolutely", "definitely", "without_a_doubt"],
    ["maybe", "ask_again_later", "try_again"],             
    ["no", "very_doubtful", "i_dont_think_so"]          
];

function get_response() {
    const outer_index = Math.floor(Math.random() * responses.length);
    const inner_list = responses[outer_index];
    const inner_index = Math.floor(Math.random() * inner_list.length);
    const answer = inner_list[inner_index];   
    
    document.getElementById("response").src = "images/" + answer + ".png";
    document.getElementById("8ball").value = "";
}