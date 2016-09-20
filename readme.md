**Quick Intro**

Xocolatl is an HTTP server created in both Swift and Objective-C. It is a proof of concept that we can leverage Swift in a way that's both fun and easy to use.

**Architecture**

The server will follow these steps when receiving an HTTP request.

1. **Sockets** -> These classes are in charge of the communication with clients who send HTTP requests. This layer is powered by GCDAsyncSocket and consists of two classes: `ServerSocket` and `RequestSocket`. `ServerSocket` handles the initial interaction with the client. Its only purpose is to assign a `RequestSocket` to an incoming HTTPRequest. `RequestSocket` will handle all the actual reading/writing for this client's request.

2. **Parsing** -> Once a `RequestSocket` establishes TLS, it will begin reading whatever request the client has sent. It will read the headers and parse them, and, in its default implementation, save the body to memory temporarily. Once all the information is parsed, `RequestSocket` will be responsible for sending an HTTP response to the client.

3. **Routing** -> Whenever `RequestSocket` believes it has the entirety of the client's request, it will send a `Request` to its delegate, which will have to provide a valid HTTP response. The `Router` class will attempt to pair a `Request` with one of its own registered `<Routable>` objects.

4. **Responding** -> When the `Router` finds a suitable candidate for responding to a `Request` it will forward its request and expect an `<HTTPResponsive>` object in turn. This object will be sent back to the Parsing layer, where it will be written out the socket, thus resetting the connection and freeing that `RequestSocket` to listen for more requests.

**Author**

Fernando Olivares

Twitter: @olivaresf
