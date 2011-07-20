The HTTP toolkit
================

Documentation is asking why you don't write it.


TODO
----

- Proxying via EM.enable_proxy
- Serving via file system and in-memory
- Usage for integration testing
- Contents of env hash
- Headers with multiple values
- Rack Handler
- Support for keep-alive connections
- Investigate MVM support in JRuby/Rubinius/MRI
- Support for SPDY
- Investigate preforking and letting multiple EventMachine loops listen on a shared socket
- Support for X-Sendfile header
- Deamonizing & dropping privileges

- Fix http_parser.rb's parsing of chunked bodies
- Does http_parser.rb recognize trailing headers?
- Support for pausing and resuming parsing/building
- Encoding support (see https://github.com/tmm1/http_parser.rb/pull/1)
