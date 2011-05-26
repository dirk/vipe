_ = (require 'underscore')._
sys = require 'sys'
fs = require 'fs'
xml2js = require 'xml2js'
events = require 'events'
pass = null

ensure_array = (array) ->
  if _.isUndefined(array)
    []
  else
    if _.isArray array then array else [array]

exports.run = ->
  unless process.argv.length == 3
    console.log 'No file given!'
    return
  file = process.argv.slice 2
  
  new Vipe.Parser fs.readFileSync("./#{file}"), (vipe) ->
    vipe.run()

class Element
  # Mocking an XML element.
  constructor: (data) ->
    @attributes = {}
    @content = ''
    
    # Set up the attributes attribute and apply all attributes directly to the object for convenience.
    if data['@']
      @attributes = data['@']
    _(@attributes).each (value, key) =>
      this[key] = value
    
    # Make sure that it's content are set.
    if _.isString data
      @content = data
    else
      @content = data['#']
  
  c: -> @content
  a:(attr) ->
    if attr then @attributes[attr] else @attributes

Vipe =
  debug: true
  Parser: class
    constructor: (raw_xml, callback) ->
      @nodes = {}
      @libs = {}
      @starts = []
      @next_thread = 1
      @threads = []
      
      parser = new xml2js.Parser
      parser.addListener 'end', (result) =>
        #_(result.lib)
        if result.head
          _(ensure_array result.head.lib).each (lib) =>
            this.lib((new Element(lib)).content)
        _(ensure_array(result.nodes.node)).each (node) =>
          this.node node
        @starts = ensure_array(result.head.start)
        
        callback this
      parser.parseString raw_xml
    run: ->
      for start in @starts
        @nodes[start].start this.open_thread()
    open_thread: ->
      old = @next_thread
      @threads.push @next_thread++
      return old
    close_thread: (t) ->
      index = @threads.indexOf(t);
      if index != -1
        @threads.splice(index, 1);
        if Vipe.debug
          console.log "- Thread #{t} closed"
    node: (node_data) ->
      #console.log(@types)
      #console.log(node_data['@']['type'])
      try
        @nodes[node_data['@']['id']] = new @libs[node_data['@']['type']](
          node_data['@']['id'],
          node_data['@']['type'],
          (new Element(e)) for e in ensure_array(node_data['input']),
          (new Element(e)) for e in ensure_array(node_data['output']),
          (new Element(e)) for e in ensure_array(node_data['reference']),
          (new Element(e)) for e in ensure_array(node_data['value']),
          this
        )
      catch e
        if e.type is 'called_non_callable'
          console.log "Could not find library type '#{node_data['@']['type']}'"
        else
          throw e
      
    
    lib: (name) ->
      if libs[name].nodes
        _(libs[name].nodes).each (val, key) =>
          @libs[name+'.'+key] = val
      
  Node: class extends events.EventEmitter
    constructor: (@id, @type, inputs, outputs, references, values, @parent) ->
      @inputs = {}
      @outputs = {}
      @references = {}
      @values = {}
      @threads = {}
      
      _(inputs).each (input) =>
        @inputs[input.name] = new Vipe.NodeInput(input.name, this, input.content)
      _(outputs).each (output) =>
        @outputs[output.name] = new Vipe.NodeOutput(output.name, this, output.content)
      _(references).each (reference) =>
        @references[reference.name] = new Vipe.NodeReference(reference.name, this, reference.content)
      
      i = 0
      _(values).each (value) =>
        if value.key
          @values[value.key] = value.content
        else
          @values[i] = value.content
          i++
    ensure_thread: (thread) ->
      unless @threads[thread]
        @threads[thread] = {inputs: {}, outputs: {}, references: {}}
    
    inputs_filled: (thread) ->
      _.size(@threads[thread].inputs) == _.size(@inputs)
    references_filled: (thread) ->
      _.size(@threads[thread].references) == _.size(@references)
    
    ping_inputs: (thread, except = false) ->
      this.ensure_thread(thread)
      _(@inputs).each (input) =>
        if (except != false and input.source != except) or !except
          input.ping(thread)
    
    input: (name, source, object, thread) ->
      this.ensure_thread(thread)
      @threads[thread].inputs[name] = object
      if this.inputs_filled(thread)
        this.emit('inputs', thread, @threads[thread].inputs)
      else
        this.ping_inputs thread, source
      
    reference: (name, source, object, thread) ->
      this.ensure_thread(thread)
      @threads[thread].references[name] = object
      if this.inputs_filled(thread)
        this.emit('reference', thread, object)
      if this.references_filled(thread)
        this.emit('references', thread, @threads[thread].references)
    ping: (name, dest, thread) ->
      #pass
      if Vipe.debug
        console.log "- Ping to #{name} from #{dest} on thread #{thread}"
    start: (thread) ->
      this.ping_inputs(thread)
      
  NodeInput: class
    constructor: (@name, @node, source) ->
      parts = source.split('/')
      @source = parts[0]
      if parts[1]
        @output = parts[1]
      else @output = false
    ping: (thread) ->
      @node.parent.nodes[@source].ping(@name, @node.id, thread)
  NodeOutput: class
    constructor: (@name, @node, source) ->
      parts = source.split('/')
      @dest = parts[0]
      if parts[1]
        @input = parts[1]
      else @input = false
  NodeReference: class
    constructor: (@name, @node, source) ->
      parts = source.split('/')
      @source = parts[0]
      if parts[1]
        @output = parts[1]
      else @output = false


http = require 'http'

libs =
  core:
    types:
      string: class
        constructor: (@value) ->
          @type = 'core/string'
      hash: class
        constructor: (@value) ->
          @type = 'core/hash'
    nodes:
      string: class extends Vipe.Node
        value: ->
          _(@values).values().join ''
        ping: (name, dest, thread) ->
          super
          output = (output for output in _(@outputs).values() when output.dest == dest)[0]
          @parent.nodes[output.dest].input(output.input, @id, this.value(), thread)
      hash: class extends Vipe.Node
        ping: (name, dest, thread) ->
          super
          output = (output for output in _(@outputs).values() when output.dest == dest)[0]
          @parent.nodes[output.dest].input(output.input, @id, @values, thread)

  http:
    types:
      response: class
        constructor: (@server, @request, @response) ->
          @type = 'http/response'
    nodes:
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
                @parent.nodes[output.dest].input(output.input, @id, new libs.http.types.response(this.server, req, res), @parent.open_thread())
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





#console.log fs.readFileSync '../example.xml'

#console.log 'there'
#console.log xml2js.Parser

#console.log (fs.readFileSync '../example.xml').toString()



#console.log (new Vipe.Node).emit