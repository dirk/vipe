Vipe = require 'vipe'
_ = (require 'underscore')._

types =
  string: class
    constructor: (@value) ->
      @type = 'core/string'
  hash: class
    constructor: (@value) ->
      @type = 'core/hash'
nodes =
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

exports.lib =
  types: types
  nodes: nodes