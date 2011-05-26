util = require('util')
exec = require('child_process').exec
_ = require('underscore')._

name = 'http'

libs = ['core', 'http']

task('build', (->
  processed = 0
  successes = 0
  total = libs.length
  console.log "[lib]\tBuilding the following libraries: #{libs.join ', '}. This may take a moment."
  _(libs).each (name) ->
    child = exec "coffee -c ./lib/libs/#{name}.coffee", (error, stdout, stderr) ->
      processed++
      if (error != null)
        console.log("[lib]\tError building #{name}:\n" + error + "\n")
      else
        successes++
        console.log "[lib]\t#{name} built"
      if processed == total
        console.log "[lib]\t#{successes}/#{total} libraries successfully built"
        complete()
), true)