package main

import (
	"encoding/json"
	"log"
	"me/tic-tac-toe/game"
	"net/http"

	"github.com/gorilla/handlers"
	"github.com/gorilla/websocket"
)

type webSocketHandler struct {
	upgrader websocket.Upgrader
	queue    chan userConn
}

func (wsh webSocketHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	c, err := wsh.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("error %s when upgrading connection to websocket", err)
		return
	}
	log.Println("Adding to queue.")
	data_type, data, err := c.ReadMessage()
	if err != nil {
		log.Printf("error %s when upgrading connection to websocket", err)
		return
	}
	if data_type != websocket.TextMessage {
		log.Printf("Bad data received for token: %s", data)
		return
	}
	username, err := validate(data[len("token: "):])
	if err != nil {
		c.WriteMessage(websocket.TextMessage, []byte("error: validation error"))
		c.Close()
		return
	}
	c.WriteMessage(websocket.TextMessage, []byte("Joined lobby"))
	wsh.queue <- userConn{c, username}
}

func validate(b []byte) (string, error) {
	client := http.DefaultClient

	req, _ := http.NewRequest("GET", "https://user3148951tic-tac-toe.auth.us-east-1.amazoncognito.com/oauth2/userInfo", nil)
	// ...
	req.Header.Add("Content-Type", "application/x-amz-json-1.1")
	req.Header.Add("Authorization", "Bearer "+string(b))

	resp, err := client.Do(req)
	if err != nil {
		log.Printf("error %s when authenticating", err)
		return "", err
	}
	var data map[string]interface{}
	// log.Printf("resp length: %d", resp.ContentLength)
	token := make([]byte, resp.ContentLength)
	resp.Body.Read(token)
	json.Unmarshal(token, &data)
	if data["username"] != nil {
		log.Printf("data: %v\n", data)
		return data["username"].(string), nil
	} else {
		return "", err
	}
}

func RemoveIndex(s []game.Game, index int) []game.Game {
	return append(s[:index], s[index+1:]...)
}

func removeGame(game *game.Game, slice *[]game.Game) bool {
	found := false
	i := 0
	for ; i < len(*slice); i++ {
		if game == &(*slice)[i] {
			found = true
			break
		}
	}
	if !found {
		return false
	}
	// log.Printf("removing game: %#v, %d", game, i)
	*slice = RemoveIndex(*slice, i)
	return true
}

type userConn struct {
	c        *websocket.Conn
	username string
}

func matchmaking(games []game.Game, queue chan userConn, finished chan *game.Game) {
	for {
		select {
		case f := <-finished:
			if !removeGame(f, &games) {
				log.Println("Trying to delete a game that doesn't exist!")
			}
		case usercon := <-queue:
			if len(games) == 0 {
				games = append(games, game.Game{Finished: finished})
			}
			last_game := &games[len(games)-1]
			if last_game.PlayerCount() == 2 {
				games = append(games, game.Game{Finished: finished})
				last_game = &games[len(games)-1]
			}
			last_game.AddPlayer(usercon.c, usercon.username)
			if last_game.PlayerCount() == 2 {
				last_game.Start()
			}
			// log.Printf("%#v", games)
		}
	}
}

func main() {
	queue := make(chan userConn)
	finished := make(chan *game.Game)
	games := make([]game.Game, 0)

	webSocketHandler := webSocketHandler{
		upgrader: websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }},
		queue:    queue,
	}
	router := http.NewServeMux()
	router.Handle("/", webSocketHandler)

	headersOk := handlers.AllowedHeaders([]string{"X-Requested-With"})
	// originsOk := handlers.AllowedOrigins([]string{os.Getenv("ORIGIN_ALLOWED")})
	originsOk := handlers.AllowedOrigins([]string{"*"})
	methodsOk := handlers.AllowedMethods([]string{"GET", "HEAD", "POST", "PUT", "OPTIONS"})

	go matchmaking(games, queue, finished)

	log.Print("Starting server...")
	log.Fatal(http.ListenAndServe(":8080", handlers.CORS(originsOk, headersOk, methodsOk)(router)))
}
