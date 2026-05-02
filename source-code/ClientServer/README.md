# TCP Client/Server Example

**Book:** [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook) by Mark Watson — [read free online](https://leanpub.com/haskell-cookbook/read)

**Book Chapter:** [Section 1 - Tutorial](https://leanpub.com/read/haskell-cookbook/section-1---tutorial)

A simple TCP client/server pair demonstrating network programming in Haskell using the `network-simple` library. The server listens for connections and the client sends a request, illustrating basic socket I/O.

## Run

Build both executables:

```bash
stack build
```

Then in **two separate terminal windows**:

```bash
# Terminal 1 — start the server
stack exec Server

# Terminal 2 — connect with the client
stack exec Client
```

![TCP client-server networking architecture](FIG_ClientServer.jpg)

## Source Files

| File | Description |
|------|-------------|
| `Server.hs` | TCP server that listens for connections |
| `Client.hs` | TCP client that connects and sends data |

## License

Apache 2.0 — Copyright 2016-2026 Mark Watson. All rights reserved.