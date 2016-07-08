# erlang-decimal
## Very basic arbitrary-precision decimal library for Erlang

Only supports basic operations. Not optimized for speed.

Addition:

    decimal:as_binary(decimal:sum(decimal:new(2, 1), decimal:new(2, 0))) -> <<"2.2">>

Subtraction:

    decimal:as_binary(decimal:sub(decimal:new(2, 1), decimal:new(2, 0))) -> <<"-1.8">>

Multiplication:

    decimal:as_binary(decimal:mul(decimal:new(2, 1), decimal:new(2, 0))) -> <<"0.40">>

Division:

    decimal:as_binary(
        decimal:ddiv(decimal:new(100, 5), decimal:new(3, 0))
    ) -> <<"0.0003333333333333">>
    decimal:as_binary(
        decimal:ddiv(decimal:new(100, 5), decimal:new(3, 0), 32)
    ) ->  <<"0.00033333333333333333333333333333">>
