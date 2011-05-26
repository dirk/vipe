# vipe

_The very venomous visual programming environment._

The __vipe__ ecosystem consists of a standard for defining visual programs (see `example.xml`), an interpreter that executes programs written in the standard, and (coming soon) a web-based editor for creating programs.

## Requirements

* `node.js`
* `npm`
* `xml2js`
* Some patience

## Install & Usage

    npm install vipe
    
    vipe program.xml

__Please note__, if you're going to be hacking from source, remember to call `jake build` after downloading the source and after modifying any of the libraries, then call `npm link`! If you add a library that's written in CoffeeScript, add it to the `libs` array in the Jakefile so that it will be converted to JavaScript.

# Contributing

Fork and pull, baby! Current big-ticket items are __documentation (and comments)__, building an easily extensible __library system__ so that anyone can write nodes to use in their programs, and putting together the __web editor__. Feel free to post issues or send me a tweet [@esherido](http://twitter.com/esherido) (I gladly accept any non-sketchy/spammy/botty follow requests).

# MIT License

Copyright (C) 2011 by Dirk Gadsden

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.