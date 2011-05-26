_ = (require 'underscore')._
path = require 'path'
sys = require 'sys'
fs = require 'fs'
xml2js = require 'xml2js'
events = require 'events'
pass = null

# http://stackoverflow.com/questions/1418050/string-strip-for-javascript
if typeof(String.prototype.trim) == "undefined"
  String.prototype.trim = -> 
    return String(this).replace(/^\s+|\s+$/g, '')

ensure_array = (array) ->
  if _.isUndefined(array)
    []
  else
    if _.isArray array then array else [array]

exports.run = ->
  # Startup system for use with the command line.
  unless process.argv.length == 3
    console.log 'No file given!'
    return
  file = (process.argv.slice 2).join('')
  
  # Print out the version
  if file.trim() == '-v'
    console.log Vipe.version
    return
  
  # Initialize the parser with the files contents.
  new Vipe.Parser fs.readFileSync("./#{file}"), (vipe) ->
    # Once it's loaded then run the program.
    vipe.run()

class Element
  # Contains an XML element so that it's data can be easily accessed.
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
  version: '0.0.2'
  # Paths to search on for libraries (currently not implemented)
  lib_path: [path.join path.dirname(fs.realpathSync __filename), '../lib/libs']
  # Best to leave this to true for now.
  debug: true
  Parser: class
    # The good stuff.
    constructor: (raw_xml, callback) ->
      @nodes = {} # All the nodes in the current system.
      @libs = {} # Stores the loaded libraries.
      @starts = [] # List of nodes to call .start(thread) on.
      @next_thread = 1 # The counter for the next thread to initialize.
      @threads = [] # List of currently running threads.
      
      parser = new xml2js.Parser
      parser.addListener 'end', (result) =>
        if result.head
          # Load each library you find in the head
          _(ensure_array result.head.lib).each (lib) =>
            this.lib((new Element(lib)).content)
          # Make sure you have somewhere to begin.
          @starts = ensure_array(result.head.start)
        # Go through each node and initialize it.
        _(ensure_array(result.nodes.node)).each (node) =>
          this.node node
        # Fire off that callback once everything is done.
        callback this
      
      # Finally, parse that raw data.
      parser.parseString raw_xml
    run: ->
      if @starts.length == 0
        console.log '[prsr] No starting nodes specified, aborting!'
        process.exit()
      for start in @starts
        @nodes[start].start this.open_thread()
    open_thread: ->
      # Utility to open a new processing thread.
      old = @next_thread
      @threads.push @next_thread++
      return old
    close_thread: (t) ->
      # Mark a thread as closed.
      index = @threads.indexOf(t);
      if index != -1
        @threads.splice(index, 1);
        if Vipe.debug
          console.log "[thrd]\t##{t} closed (#{@threads.join ', '} still open)"
    node: (node_data) ->
      # Initialize a node.
      try
        # Splits http.res.write into 'http' and 'res.write'.
        parts = node_data['@']['type'].split('.')
        lib_name = parts[0]
        node_nade = parts[1..].join('.')
        # Store the node by it's ID/name in the @nodes object and initialize the node object with it's data.
        @nodes[node_data['@']['id']] = new @libs[lib_name].nodes[node_nade](
          node_data['@']['id'],
          node_data['@']['type'], # Note, this is the class of the node; not to be confused with data types.
          (new Element(e)) for e in ensure_array(node_data['input']),
          (new Element(e)) for e in ensure_array(node_data['output']),
          (new Element(e)) for e in ensure_array(node_data['reference']),
          (new Element(e)) for e in ensure_array(node_data['value']),
          this
        )
      catch e
        if e.type is 'called_non_callable'
          console.log "Could not find library node type '#{node_data['@']['type']}'"
        else
          throw e
      
    
    lib: (name) ->
      # Load a library
      # TODO: Make this actually scan all available lib_path's
      sys.print "[lib]\t#{name} loading... "
      
      lib_path = path.join(Vipe.lib_path[0], name)
      failed = true
      try
        stat = fs.lstatSync(lib_path+'.js')
        failed = false
        
        @libs[name] = require(lib_path).lib
        if _.isFunction(@libs[name].loaded)
          @libs[name].loaded(this)
        console.log 'Done'
      catch e
        pass
      
      if failed
        console.log 'Failed'
        console.log "[lib]\tCould not find library '#{name}'"
        console.log "[lib]\tLibrary load path:"
        console.log Vipe.lib_path
      
  Node: class extends events.EventEmitter
    # Foundation for all nodes; make sure to call super whenever you override constructor!
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
    # Make a thread object has been created for the current thread!
    ensure_thread: (thread) ->
      unless @threads[thread]
        @threads[thread] = {inputs: {}, outputs: {}, references: {}}
    
    inputs_filled: (thread) ->
      _.size(@threads[thread].inputs) == _.size(@inputs)
    references_filled: (thread) ->
      _.size(@threads[thread].references) == _.size(@references)
    
    # Reaches out to every input and gives it a handy tap.
    # Can specify an input name as the second variable to tell it not to tap a specific input.
    ping_inputs: (thread, except = false) ->
      this.ensure_thread(thread)
      _(@inputs).each (input) =>
        if (except != false and input.source != except) or !except
          input.ping(thread)
    # Called by another node (source) to put an input "letter" (object) into one of its "mailboxes" (name).
    input: (name, source, object, thread) ->
      this.ensure_thread(thread)
      @threads[thread].inputs[name] = object
      if this.inputs_filled(thread)
        this.emit('inputs', thread, @threads[thread].inputs)
      else
        this.ping_inputs thread, source
    # Same as input, except with references.
    reference: (name, source, object, thread) ->
      this.ensure_thread(thread)
      @threads[thread].references[name] = object
      if this.inputs_filled(thread)
        this.emit('reference', thread, object)
      if this.references_filled(thread)
        this.emit('references', thread, @threads[thread].references)
    # Overrride this (remember to call super!) to handle incoming pings.
    ping: (name, dest, thread) ->
      if Vipe.debug
        console.log "[ping]\tto #{name} from #{dest} on thread #{thread}"
    # Called by Vipe.Parser. Override if necessary; default is to call this.ping_inputs for the specified thread;
    # although this may not be necessary.
    start: (thread) ->
      this.ping_inputs(thread)
  # Classes to store data for inputs, references, and outputs.
  # Note that @node refers to the @parent, not the source/destination, node.
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


exports.Node = Vipe.Node