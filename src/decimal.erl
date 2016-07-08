-module(decimal).

-export([from_binary/1, as_binary/1]).
-export([equals/2]).
-export([new/2]).
-export([sum/2]).
-export([sub/2]).
-export([mul/2]).
-export([ddiv/2,ddiv/3]).

-record(decimal, {unscaled, scale}).

%% Convert a binary string to a Decimal representation
from_binary(undefined) -> undefined;
from_binary(Binstring) when is_binary(Binstring) ->
    from_binary(binary_to_list(Binstring));
from_binary(IntList) when is_list(IntList) ->
    Integer = erlang:list_to_integer(lists:takewhile(fun(C) -> C /= $. end, IntList)),
    DecimalPart = lists:dropwhile(fun(C) -> C /= $. end, IntList),
    Decimal = case DecimalPart of
                  [] -> [];
                  [$.|Numbers] -> Numbers
               end,
    Scale = length(Decimal),
    DecimalInteger = case Decimal of
                         [] -> 0;
                         N -> list_to_integer(N)
                    end,
    Unscaled = if Integer >= 0 ->
                   (Integer * intpow(10, Scale)) + DecimalInteger;
                  true ->
                   (Integer * intpow(10, Scale)) - DecimalInteger
                end,
    #decimal{unscaled=Unscaled, scale=Scale}.

%% Construct a new decimal from a raw number and scalar
new(Unscaled, Scale) -> #decimal{unscaled=Unscaled, scale=Scale}.

%% Convert a Decimal to a binary string representation
as_binary(#decimal{unscaled=Unscaled, scale=0}) ->
    erlang:integer_to_binary(Unscaled);
as_binary(#decimal{unscaled=Unscaled, scale=Scale}) ->
    Tenscale = intpow(10, Scale),
    Integer = integer_to_binary(Unscaled div Tenscale),
    Decimal = integer_to_binary(abs(Unscaled rem Tenscale)),
    Zeropad = erlang:list_to_binary(
        lists:duplicate(
          Scale - length(binary_to_list(Decimal)), $0)),
    <<Integer/binary, <<".">>/binary, Zeropad/binary, Decimal/binary>>.

%% Integer form of the math:pow method
intpow(Base, Power) -> intpow(Base, Base, Power).
intpow(_, _, 0) -> 1;
intpow(_, Accumulator, 1) -> Accumulator;
intpow(Base, Accumulator, Power) ->
    intpow(Base, Accumulator * Base, Power - 1).

%% Check if two decimals are equal, accounting for scale
equals(D1=#decimal{}, D2=#decimal{}) ->
    {#decimal{unscaled=S1}, #decimal{unscaled=S2}} = rescale(D1, D2),
    S1 == S2.

%% Rescale two decimals to the same scale
rescale(D1=#decimal{unscaled=U1, scale=S1}, D2=#decimal{unscaled=U2, scale=S2}) ->
    if S1 >= S2 ->
         Delta = S1 - S2,
         {D1,
          #decimal{
             unscaled = U2 * intpow(10, Delta),
             scale = S1
         }};
    true ->
         Delta = S2 - S1,
         {#decimal{
             unscaled = U1 * intpow(10, Delta),
             scale = S2
         },
         D2}
    end;
%% Rescale a single decimal to a specified scale, potentially losing information
rescale(#decimal{unscaled=U, scale=S}, Scale) when is_integer(Scale) ->
    case Scale > S of
        true ->
            #decimal{
                unscaled=U * intpow(10, Scale - S),
                scale=Scale
                };
        false ->
            #decimal{
                unscaled=U div intpow(10, S - Scale),
                scale=Scale
            }
    end.


%% Sum two decimals
sum(D1=#decimal{}, D2=#decimal{}) ->
    {#decimal{unscaled=S1, scale=Scale}, #decimal{unscaled=S2}} = rescale(D1, D2),
    #decimal{
       unscaled = S1 + S2,
       scale = Scale
      }.

%% Subtract one decimal from another. Sub(A, B) is equivalent to A - B.
sub(D1=#decimal{}, D2=#decimal{}) ->
    {#decimal{unscaled=S1, scale=Scale}, #decimal{unscaled=S2}} = rescale(D1, D2),
    #decimal{
       unscaled = S1 - S2,
       scale = Scale
      }.

%% Multiple one decimal by another
mul(D1=#decimal{}, D2=#decimal{}) ->
    {#decimal{unscaled=S1, scale=Scale}, #decimal{unscaled=S2}} = rescale(D1, D2),
    #decimal{
       unscaled = S1 * S2,
       scale = Scale + Scale
      }.

%% Divide one decimal by another (D1 / D2) with default precision
ddiv(D1=#decimal{}, D2=#decimal{}) ->
    ddiv(D1, D2, 16).

%% Divide one decimal by another (D1 / D2) with custom precision
ddiv(D1=#decimal{}, #decimal{unscaled=U2, scale=S2}, Precision) ->
    #decimal{unscaled=U1, scale=S1} = rescale(D1, S2 + Precision),
    #decimal{
       unscaled=U1 div U2,
       scale=S1 - S2
    }.

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

intpow_test_() ->
    Cases = [
        {"three_to_zero", 3, 0, 1},
        {"three_to_one", 3, 1, 3},
        {"three_to_two", 3, 2, 9},
        {"ten_squared", 10, 2, 100},
        {"12_to_10", 12, 10, 61917364224}
    ],
    [{Descriptor, ?_assertEqual(Expected, intpow(Base, Exponent))}
        || {Descriptor, Base, Exponent, Expected} <- Cases
    ]
.

equals_test_() ->
    Cases = [
        {
            "same_same_scale",
            #decimal{unscaled=123456, scale=3},
            #decimal{unscaled=123456, scale=3},
            true
        },
        {
            "same_diff_scale",
            #decimal{unscaled=1234560, scale=4},
            #decimal{unscaled=123456, scale=3},
            true
        },
        {
            "diff_same_scale",
            #decimal{unscaled=123456, scale=3},
            #decimal{unscaled=789123, scale=3},
            false
        },
        {
            "diff_diff_scale",
            #decimal{unscaled=123456, scale=3},
            #decimal{unscaled=789123, scale=4},
            false
        }
    ],
    [{Descriptor, ?_assertEqual(Expected, equals(Term1, Term2))}
        || {Descriptor, Term1, Term2, Expected} <- Cases
    ]
.

rescale_test_() ->
    Cases = [
        {
            "same_scale",
            #decimal{unscaled=123456, scale=3},
            #decimal{unscaled=789123, scale=3},
            {#decimal{unscaled=123456, scale=3}, #decimal{unscaled=789123, scale=3}}
        },
        {
            "s1_larger",
            #decimal{unscaled=123456, scale=4},
            #decimal{unscaled=789123, scale=3},
            {#decimal{unscaled=123456, scale=4}, #decimal{unscaled=7891230, scale=4}}
        },
        {
            "s2_larger",
            #decimal{unscaled=123456, scale=3},
            #decimal{unscaled=789123, scale=4},
            {#decimal{unscaled=1234560, scale=4}, #decimal{unscaled=789123, scale=4}}
        }
    ],
    [{Descriptor, ?_assertEqual(Expected, rescale(Base, Exponent))}
        || {Descriptor, Base, Exponent, Expected} <- Cases
    ]
.

sums_test_() ->
    Cases = [
        {
            "same_scale",
            #decimal{unscaled=123456, scale=3},
            #decimal{unscaled=789123, scale=3},
            #decimal{unscaled=912579, scale=3}
        },
        {
            "s1_larger",
            #decimal{unscaled=123456, scale=4},
            #decimal{unscaled=789123, scale=3},
            #decimal{unscaled=8014686, scale=4}
        },
        {
            "s2_larger",
            #decimal{unscaled=123456, scale=3},
            #decimal{unscaled=789123, scale=4},
            #decimal{unscaled=2023683, scale=4}
        }
    ],
    [{Descriptor, ?_assertEqual(Expected, sum(Base, Exponent))}
        || {Descriptor, Base, Exponent, Expected} <- Cases
    ]
.

muls_test_() ->
    Cases = [
        {
            "same_scale",
            #decimal{unscaled=123456, scale=3},
            #decimal{unscaled=789123, scale=3},
            #decimal{unscaled=97421969088, scale=6}
        },
        {
            "s1_larger",
            #decimal{unscaled=123456, scale=4},
            #decimal{unscaled=789123, scale=3},
            #decimal{unscaled=97421969088, scale=7}
        },
        {
            "s2_larger",
            #decimal{unscaled=123456, scale=3},
            #decimal{unscaled=789123, scale=4},
            #decimal{unscaled=97421969088, scale=7}
        }
    ],
    [{Descriptor, ?_assert(equals(Expected, mul(Base, Exponent)))}
        || {Descriptor, Base, Exponent, Expected} <- Cases
    ]
.

subs_test_() ->
    Cases = [
        {
            "same_scale",
            #decimal{unscaled=123456, scale=3},
            #decimal{unscaled=789123, scale=3},
            #decimal{unscaled=-665667, scale=3}
        },
        {
            "s1_larger",
            #decimal{unscaled=123456, scale=4},
            #decimal{unscaled=789123, scale=3},
            #decimal{unscaled=-7767774, scale=4}
        },
        {
            "s2_larger",
            #decimal{unscaled=123456, scale=3},
            #decimal{unscaled=789123, scale=4},
            #decimal{unscaled=445437, scale=4}
        }
    ],
    [{Descriptor, ?_assertEqual(Expected, sub(Base, Exponent))}
        || {Descriptor, Base, Exponent, Expected} <- Cases
    ]
.

convert_strings_to_decimals_test_() ->
    Cases = [
        { "test_integer", <<"463">>, #decimal{unscaled=463, scale=0} },
        { "test_integer_with_point", <<"463.0">>, #decimal{unscaled=4630, scale=1} },
        { "test_float", <<"463.123">>, #decimal{unscaled=463123, scale=3} },
        { "test_float_decimal_leading_zero", <<"463.0123">>, #decimal{unscaled=4630123, scale=4} },
        { "test_negative", <<"-463">>, #decimal{unscaled=-463, scale=0} },
        { "test_negative_float", <<"-463.123">>, #decimal{unscaled=-463123, scale=3} }
    ],
    [{Descriptor, ?_assertEqual(Expected, from_binary(Raw))}
        || {Descriptor, Raw, Expected} <- Cases
    ]
.

convert_decimals_to_strings_test_() ->
    Cases = [
        { "test_integer", #decimal{unscaled=463, scale=0}, <<"463">>},
        { "test_integer_with_point", #decimal{unscaled=4630, scale=1}, <<"463.0">> },
        { "test_float", #decimal{unscaled=463123, scale=3}, <<"463.123">> },
        { "test_float_decimal_leading_zero", #decimal{unscaled=4630123, scale=4}, <<"463.0123">> },
        { "test_negative", #decimal{unscaled=-463, scale=0}, <<"-463">> },
        { "test_negative_float", #decimal{unscaled=-463123, scale=3}, <<"-463.123">> }
    ],
    [{Descriptor, ?_assertEqual(Expected, as_binary(Raw))}
        || {Descriptor, Raw, Expected} <- Cases
    ]
.


-endif.
