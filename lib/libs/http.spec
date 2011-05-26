{
  "name": "http",
  "description": "Provides functionality for creating an HTTP server",
  "version": "0.0.1",
  "author": "dirk",
  "types": {
    "response": {
      "description": "Stores the server, request, and response objects"
    }
  },
  "nodes": {
    "server": {
      "inputs": {
        "port": { "types": ["core/string", "core/integer"] },
        "host": { "types": ["core/string"] }
      },
      "outputs": {
        "response": { "types": ["http/response"] }
      },
      "references": {}
    },
    "res.writeHead": {
      "inputs": {
        "response": { "types": ["http/response"] },
        "hash": { "types": ["core/hash"] }
      },
      "outputs": {
        "response": { "types": ["http/response"] }
      },
      "references": {}
    },
    "res.write": {
      "inputs": {
        "response": { "types": ["http/response"] },
        "string": { "types": ["core/string"] }
      },
      "outputs": {
        "response": { "types": ["http/response"] }
      },
      "references": {}
    },
    "close": {
      "inputs": {
        "response": { "types": ["http/response"] }
      },
      "references": {}
    }
  }
}