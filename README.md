Builds and parses HTTP messages
===============================

Hatetepe combines its own builder with http_parser.rb to make dealing with HTTP
messages as comfortable as possible.

TODO
----

- Does http_parser.rb recognize trailing headers?
- Support for pausing and resuming parsing/building
- Encoding support (see https://github.com/tmm1/http_parser.rb/pull/1)
