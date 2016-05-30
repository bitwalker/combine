Definitions.

IDENTIFIER = [a-z_]+
WHITESPACE = [\s\t\n\r]

Rules.

{IDENTIFIER}  : {token, {identifier, TokenLine, TokenChars}}.
SELECT        : {token, {select, TokenLine}}.
FROM          : {token, {from, TokenLine}}.
,             : {token, {comma, TokenLine}}.
{WHITESPACE}+ : skip_token.

Erlang code.
