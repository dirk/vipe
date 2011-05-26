http = require 'http'
Vipe = require 'vipe'
_ = (require 'underscore')._

types =
  response: class
    constructor: (@server, @request, @response) ->
      @type = 'http/response'
nodes =
  'server': class extends Vipe.Node
    constructor: ->
      super
      
      @server = null
      
      this.on 'inputs', (thread, inputs) =>
        ###
        http.createServer(function (req, res) {
          res.writeHead(200, {'Content-Type': 'text/plain'});
          res.end('Hello World\n');
        }).listen(1337, "127.0.0.1");
        console.log('Server running at http://127.0.0.1:1337/');
        ###
        output = @outputs.response
        if !@server
          @server = http.createServer((req, res) =>
            @parent.nodes[output.dest].input(output.input, @id, new types.response(this.server, req, res), @parent.open_thread())
          )
          @server.listen(parseInt(inputs.port), inputs.host)
  'res.writeHead': class extends Vipe.Node
    constructor: ->
      super
      
      this.on 'inputs', (thread, inputs) =>
        inputs.response.response.writeHead(200, inputs.hash)
        output = @outputs.response
        @parent.nodes[output.dest].input(output.input, @id, inputs.response, thread)
        
  'res.write': class extends Vipe.Node
    constructor: ->
      super
      
      this.on 'inputs', (thread, inputs) =>
        inputs.response.response.write(inputs.string)
        output = @outputs.response
        @parent.nodes[output.dest].input(output.input, @id, inputs.response, thread)
  'close': class extends Vipe.Node
    constructor: ->
      super
      
      this.on 'inputs', (thread, inputs) =>
        inputs.response.response.end()
        @parent.close_thread(thread)

exports.lib =
  types: types
  nodes: nodes