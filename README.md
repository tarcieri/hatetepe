The HTTP toolkit
================

Documentation is asking why you don't write it.

TODO
----

- Proxy
- Rack handler
- Code reloading
- Client
- Keep-alive
- Preforking
- Native file sending/receiving
- Contents of env hash
- MVM support via Thread Pool
- Support for SPDY
- Serving via filesystem or in-memory
- Foreman support
- Demonizing and dropping privileges
- Trailing headers

Things to check out
-------------------

- Fix http_parser.rb's parsing of chunked bodies
- Does http_parser.rb recognize trailing headers?
- Encoding support (see https://github.com/tmm1/http_parser.rb/pull/1)
- Are there any good C libs for building HTTP messages?
