# erlang-decimal
## Very basic arbitrary-precision decimal library for Erlang

Only supports basic operations. Not optimized for speed.

Addition:

    decimal:as_binary(decimal:sum(decimal:new(2, 1), decimal:new(2, 0))) -> <<"2.2">>

Subtraction:

    decimal:as_binary(decimal:sub(decimal:new(2, 1), decimal:new(2, 0))) -> <<"-1.8">>

Multiplication:

    decimal:as_binary(decimal:mul(decimal:new(2, 1), decimal:new(2, 0))) -> <<"0.40">>

Haven't needed division yet.
