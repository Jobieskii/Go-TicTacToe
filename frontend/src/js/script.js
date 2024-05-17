var turn = -1;

const urlParams = new URLSearchParams(window.location.search);
const username = urlParams.get('login');

const usernameBanner = document.getElementById('userLogin');
usernameBanner.innerHTML = username;

const socket = new WebSocket("ws://localhost:8080/" + username);

socket.addEventListener("message", handleMessage);

const messages = document.getElementById('messages');
const turnIndicator = document.getElementById('turnIndicator');
var player = -1;
var opponentUsername = '';

function handleMessage(e) {
    console.log(e.data);
    if (e.data.startsWith('Player')) {
        player = parseInt(e.data['Player '.length]) - 1;
        opponentUsername = e.data.slice('Player x;'.length);
        document.getElementById('opponentLogin').innerHTML = opponentUsername;
        turn = 0;
        if (player == 0) {
            turnIndicator.className = 'on';
        }
    }
    if (e.data.startsWith('error:')) {
        const errormessage = document.createElement('p');
        errormessage.innerText = e.data.slice('error: '.length);
        setTimeout((e) => { errormessage.remove() }, 2000);
        messages.appendChild(errormessage);
    }
    if (e.data.startsWith('result')) {
        var message = e.data.slice('result: '.length);
        if (message != 'draw') {
            message = 'Player ' + message + ' won!';
        }
        const node = document.createElement('p');
        node.innerText = message;
        messages.appendChild(node);
        window.onclick = (e) => { window.location = window.location.origin };
    }
    if (e.data.startsWith('board')) {
        [b, t] = e.data.split('; ');
        updateBoard(
            b.slice('board: '.length)
             .split(', ')
             .map((x) => parseInt(x))
        );
        turn = parseInt(t.slice('turn: '.length));
        if (turn % 2 == player) {
            turnIndicator.className = 'on';
        } else {
            turnIndicator.className = '';
        }
    }
}

function updateBoard(board) {
    board = board.map((x) => {
        if (x == -1) return 'x'
        if (x == 1) return 'o'
        return ''
    })
    for (i = 0; i < board.length; i++) {
        document.getElementById(`${i%3}_${Math.floor(i/3)}`).innerText = board[i];
    }
    
}

function playerTurn(id, text) {
    if (text === "") {
        makeAMove(id.split("_")[0], id.split("_")[1]);
    }
}

function makeAMove(xCoordinate, yCoordinate) {
    socket.send(parseInt(yCoordinate) * 3 + parseInt(xCoordinate))
}


for (element of document.getElementsByClassName("tic")) {
    element.onclick = (e) => {
        if (turn >= 0 && turn % 2 == player) {
            var slot = e.target.id;
            playerTurn(slot, e.target.innerText);
        }
    }
};