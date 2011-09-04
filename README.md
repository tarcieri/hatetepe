The HTTP toolkit
================

Documentation is asking why you don't write it.

TODO
----

- Proxy
- Code reloading
- Client
- Keep-alive
- Preforking
- Native file sending/receiving
- MVM support via Thread Pool
- Support for SPDY
- Serving via filesystem or in-memory
- Foreman support
- Daemonizing and dropping privileges
- Trailing headers
- Propagating connection errors to the app

Things to check out
-------------------

- Fix http_parser.rb's parsing of chunked bodies
- Does http_parser.rb recognize trailing headers?
- Encoding support (see https://github.com/tmm1/http_parser.rb/pull/1)
- Are there any good C libs for building HTTP messages?
