package game

import (
	"fmt"
	"log"
	"strconv"
	"strings"

	"github.com/gorilla/websocket"
)

type Game struct {
	c1        *websocket.Conn
	c2        *websocket.Conn
	username1 string
	username2 string
	board     [3][3]int
	turn      int
	started   bool
	ended     bool
	Finished  chan *Game
}

func (g *Game) post(message string) {
	if g.c1 != nil {
		g.c1.WriteMessage(websocket.TextMessage, []byte(message))
	}
	if g.c2 != nil {
		g.c2.WriteMessage(websocket.TextMessage, []byte(message))
	}
}

func (g *Game) postGameState() {
	g.post(fmt.Sprintf("board: %d, %d, %d, %d, %d, %d, %d, %d, %d; turn: %d",
		g.board[0][0], g.board[0][1], g.board[0][2], g.board[1][0], g.board[1][1], g.board[1][2],
		g.board[2][0], g.board[2][1], g.board[2][2], g.turn))
}

type BoardState int

const (
	ongoing BoardState = iota
	draw    BoardState = iota
	winner1 BoardState = iota
	winner2 BoardState = iota
)

func (g *Game) checkBoardState() BoardState {

	for i := 0; i < 3; i++ {
		sum := 0
		sum2 := 0
		for j := 0; j < 3; j++ {
			sum += g.board[i][j]
			sum2 += g.board[j][i]
		}
		if sum == -3 || sum2 == -3 {
			return winner1
		}
		if sum == 3 || sum2 == 3 {
			return winner2
		}
	}
	if g.board[0][0]+g.board[1][1]+g.board[2][2] == -3 {
		return winner1
	}
	if g.board[0][0]+g.board[1][1]+g.board[2][2] == 3 {
		return winner2
	}
	if g.board[2][0]+g.board[1][1]+g.board[0][2] == -3 {
		return winner1
	}
	if g.board[2][0]+g.board[1][1]+g.board[0][2] == 3 {
		return winner2
	}

	for i := 0; i < 3; i++ {
		for j := 0; j < 3; j++ {
			if g.board[i][j] == 0 {
				return ongoing
			}
		}
	}
	return draw
}

func (g *Game) finish(result BoardState) {
	if g.ended {
		return
	}
	g.ended = true
	if result == draw {
		g.post("result: draw")
	} else if result == winner1 {
		g.post("result: 1")
	} else if result == winner2 {
		g.post("result: 2")
	}
	if g.c1 != nil {
		g.c1.Close()
	}
	if g.c2 != nil {
		g.c2.Close()
	}
	g.Finished <- g
}
func (g *Game) Start() {
	if g.c1 != nil && g.c2 != nil {
		g.post("Starting game.")
		log.Println("Starting game.")
		g.c1.WriteMessage(websocket.TextMessage, append([]byte("Player 1;"), g.username2...))
		g.c2.WriteMessage(websocket.TextMessage, append([]byte("Player 2;"), g.username1...))
		g.started = true

	}
}
func (g *Game) PlayerCount() int {
	if g.c2 != nil {
		return 2
	}
	if g.c1 != nil {
		return 1
	}
	return 0
}

func (g *Game) AddPlayer(c *websocket.Conn, username string) {
	if g.c1 == nil {
		g.c1 = c
		g.username1 = username
		g.c1.WriteMessage(websocket.TextMessage, []byte("Awaiting player"))
		go g.makeMove(0)
	} else {
		g.c2 = c
		g.username2 = username
		go g.makeMove(1)
	}
}

func (g *Game) cancelGame() error {
	if g.ended {
		return nil
	}
	log.Println("canceled game.")
	g.post("Canceled")
	g.finish(draw)
	return nil
}

func (g *Game) makeMove(player int) {
	c := g.c1
	if player == 1 {
		c = g.c2
	} else if player != 0 {
		return
	}
	defer g.cancelGame()
	defer log.Println("client disconnected.")
	for {
		typ, p, err := c.ReadMessage()
		if err != nil {
			log.Printf("receive message error, %#v", err)
			break
		}
		if typ != websocket.TextMessage {
			log.Printf("Wrong message type, %d", typ)
			continue
		}
		if !g.started {
			continue
		}

		if g.turn%2 == player {
			message := strings.TrimSpace(string(p))
			mov, err := strconv.Atoi(message)
			if err != nil {
				c.WriteMessage(websocket.TextMessage, []byte(fmt.Sprintf("error: Wrong message (%s)", message)))
				continue
			}
			moveRes := handleMove(player, &g.board, mov)
			if moveRes > 0 {
				c.WriteMessage(websocket.TextMessage, []byte("error: Invalid move."))
				continue
			}
			g.turn += 1
			g.postGameState()
			st := g.checkBoardState()
			if st != ongoing {
				g.finish(st)
			}

		} else {
			c.WriteMessage(websocket.TextMessage, []byte("error: Not your turn."))
		}

	}
}
func handleMove(player int, board *[3][3]int, sel int) int {
	if sel > 8 {
		return 3
	}
	a := &board[sel/3][sel%3]
	if *a != 0 {
		return 1
	}

	*a = player*2 - 1
	return 0
}
