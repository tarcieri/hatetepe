Builds and parses HTTP messages
===============================

Hatetepe combines its own builder with http_parser.rb to make dealing with HTTP
messages as comfortable as possible.

TODO
----

- Does http_parser.rb recognize headers after a chunked body?
- Some headers may appear multiple times (e.g. Set-Cookie)
- Encoding support (see https://github.com/tmm1/http_parser.rb/pull/1)
- Support for stopping parsing/building
