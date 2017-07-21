-module(sr_elements_SUITE).

-include_lib("mixer/include/mixer.hrl").

-mixin([{ sr_test_utils
        , [ init_per_suite/1
          , end_per_suite/1
          ]
        }]).

-export([ all/0
        , init_per_testcase/2
        , end_per_testcase/2
        ]).
-export([ success_scenario/1
        , duplicated_key/1
        , invalid_headers/1
        , invalid_parameters/1
        , not_found/1
        , location/1
        , binary_id_conversion/1
        ]).

-spec all() -> [atom()].
all() -> sr_test_utils:all(?MODULE).

-spec init_per_testcase(atom(), sr_test_utils:config()) ->
  sr_test_utils:config().
init_per_testcase(_, Config) ->
  _ = sumo:delete_all(elements),
  Config.

-spec end_per_testcase(atom(), sr_test_utils:config()) ->
  sr_test_utils:config().
end_per_testcase(_, Config) ->
  Config.

-spec success_scenario(sr_test_utils:config()) -> {comment, string()}.
success_scenario(_Config) ->
  Headers = #{<<"content-type">> => <<"application/json; charset=utf-8">>},

  ct:comment("There are no elements"),
  #{status_code := 200, body := Body0} =
    sr_test_utils:api_call(get, "/elements"),
  [] = sr_json:decode(Body0),

  ct:comment("Element 1 is created"),
  #{status_code := 201, body := Body1} =
    sr_test_utils:api_call(
      post, "/elements", Headers,
      #{ key   => 1
       , value => <<"val1">>
       }),
  #{ <<"key">>        := 1
   , <<"created_at">> := CreatedAt
   , <<"updated_at">> := CreatedAt
   } = Element1 = sr_json:decode(Body1),

  ct:comment("Find element using query string"),
  #{status_code := 200, body := BodyA} =
    sr_test_utils:api_call(get, "/elements?value=val1"),
  [#{ <<"created_at">> := CreatedAt
   , <<"key">>        := 1
   , <<"updated_at">> := CreatedAt
   , <<"value">>      := <<"val1">>
   }] = sr_json:decode(BodyA),

  ct:comment("Find elements non existent value using query string"),
  #{status_code := 200, body := BodyB} =
    sr_test_utils:api_call(get, "/elements?novalue=noval"),
  [Element1] = sr_json:decode(BodyB),

  ct:comment("Element 1 is modified"),
  #{status_code := 422, body := Body01} =
    sr_test_utils:api_call(
      put, "/elements", #{<<"content-type">> => <<"application/json">>},
      #{ key   => 1
       , value => <<"val1">>
       }),
  #{ <<"error">> := <<"Duplicated entity">>
   } = sr_json:decode(Body01),

  ct:comment("There is one element now"),
  #{status_code := 200, body := Body2} =
    sr_test_utils:api_call(get, "/elements"),
  [Element1] = sr_json:decode(Body2),

  ct:comment("And we can fetch it"),
  #{status_code := 200, body := Body21} =
    sr_test_utils:api_call(get, "/elements/1"),
  Element1 = sr_json:decode(Body21),

  ct:comment("The element value can be changed"),
  #{status_code := 200, body := Body3} =
    sr_test_utils:api_call(
      put, "/elements/1", Headers,
      #{ key => 1
       , value => <<"newval3">>
       }),
  #{ <<"key">>        := 1
   , <<"value">>      := <<"newval3">>
   , <<"created_at">> := CreatedAt
   , <<"updated_at">> := UpdatedAt
   } = Element3 = sr_json:decode(Body3),
  true = UpdatedAt >= CreatedAt,

  ct:comment("Still just one element"),
  #{status_code := 200, body := Body4} =
    sr_test_utils:api_call(get, "/elements"),
  [Element3] = sr_json:decode(Body4),

  ct:comment("The element value can be changed by PATCH"),
  #{status_code := 200, body := Body5} =
    sr_test_utils:api_call(
      patch, "/elements/1", Headers, #{value => <<"newval5">>}),
  #{ <<"key">>        := 1
   , <<"value">>      := <<"newval5">>
   , <<"created_at">> := CreatedAt
   , <<"updated_at">> := UpdatedAt5
   } = Element5 = sr_json:decode(Body5),
  true = UpdatedAt5 >= CreatedAt,

  ct:comment("Still just one element"),
  #{status_code := 200, body := Body6} =
    sr_test_utils:api_call(get, "/elements"),
  [Element5] = sr_json:decode(Body6),

  ct:comment("Elements can be created by PUT"),
  #{status_code := 201, body := Body7} =
    sr_test_utils:api_call(
      put, "/elements/2", Headers,
      #{ key => 2
       , value => <<"val2">>
       }),
  #{ <<"key">>        := 2
   , <<"value">>      := <<"val2">>
   , <<"created_at">> := CreatedAt7
   , <<"updated_at">> := CreatedAt7
   } = Element7 = sr_json:decode(Body7),
  true = CreatedAt7 >= CreatedAt,

  ct:comment("There are two elements now"),
  #{status_code := 200, body := Body8} =
    sr_test_utils:api_call(get, "/elements"),
  [Element7] = sr_json:decode(Body8) -- [Element5],

  ct:comment("Element1 is deleted"),
  #{status_code := 204} = sr_test_utils:api_call(delete, "/elements/1"),

  ct:comment("One element again"),
  #{status_code := 200, body := Body9} =
    sr_test_utils:api_call(get, "/elements"),
  [Element7] = sr_json:decode(Body9),

  ct:comment("DELETE is not idempotent"),
  #{status_code := 204} = sr_test_utils:api_call(delete, "/elements/2"),
  #{status_code := 404} = sr_test_utils:api_call(delete, "/elements/2"),

  ct:comment("There are no elements"),
  #{status_code := 200, body := Body10} =
    sr_test_utils:api_call(get, "/elements"),
  [] = sr_json:decode(Body10),

  {comment, ""}.

-spec duplicated_key(sr_test_utils:config()) -> {comment, string()}.
duplicated_key(_Config) ->
  Headers = #{<<"content-type">> => <<"application/json; charset=utf-8">>},
  Body =
    #{ key   => <<"element1">>
     , value => <<"val1">>
     },

  ct:comment("Element 1 is created"),
  #{status_code := 201} =
    sr_test_utils:api_call(post, "/elements", Headers, Body),

  ct:comment("Element 1 can't be created again"),
  #{status_code := 422} =
    sr_test_utils:api_call(post, "/elements", Headers, Body),

  {comment, ""}.

-spec invalid_headers(sr_test_utils:config()) -> {comment, string()}.
invalid_headers(_Config) ->
  NoHeaders = #{},
  InvalidHeaders = #{<<"content-type">> => <<"text/plain">>},
  InvalidAccept = #{ <<"content-type">> => <<"application/json">>
                   , <<"accept">> => <<"text/html">>
                   },

  ct:comment("content-type must be provided for POST and PUT"),
  #{status_code := 415} =
    sr_test_utils:api_call(post, "/elements", NoHeaders, <<>>),
  #{status_code := 415} =
    sr_test_utils:api_call(put, "/elements/noheaders", NoHeaders, <<>>),

  ct:comment("content-type must be JSON for POST and PUT"),
  #{status_code := 415} =
    sr_test_utils:api_call(post, "/elements", InvalidHeaders, <<>>),
  #{status_code := 415} =
    sr_test_utils:api_call(put, "/elements/badtype", InvalidHeaders, <<>>),

  ct:comment("Agent must accept json for POST, GET and PUT"),
  #{status_code := 406} =
    sr_test_utils:api_call(post, "/elements", InvalidAccept, <<>>),
  #{status_code := 406} =
    sr_test_utils:api_call(get, "/elements", InvalidAccept, <<>>),
  #{status_code := 406} =
    sr_test_utils:api_call(put, "/elements/badaccept", InvalidAccept, <<>>),
  #{status_code := 406} =
    sr_test_utils:api_call(get, "/elements/badaccept", InvalidAccept, <<>>),

  {comment, ""}.

-spec invalid_parameters(sr_test_utils:config()) -> {comment, string()}.
invalid_parameters(_Config) ->
  Headers = #{<<"content-type">> => <<"application/json">>},
  _ = sumo:persist(elements, sr_elements:new(1, <<"val">>)),

  ct:comment("Empty or broken parameters are reported"),
  #{status_code := 400} =
    sr_test_utils:api_call(post, "/elements", Headers, <<>>),
  #{status_code := 400} =
    sr_test_utils:api_call(put, "/elements/nobody", Headers, <<>>),
  #{status_code := 400} =
    sr_test_utils:api_call(put, "/elements/1", Headers, <<>>),
  #{status_code := 400} =
    sr_test_utils:api_call(patch, "/elements/1", Headers, <<>>),
  #{status_code := 400} =
    sr_test_utils:api_call(post, "/elements", Headers, <<"{">>),
  #{status_code := 400} =
    sr_test_utils:api_call(put, "/elements/broken", Headers, <<"{">>),
  #{status_code := 400} =
    sr_test_utils:api_call(put, "/elements/1", Headers, <<"{">>),
  #{status_code := 400} =
    sr_test_utils:api_call(patch, "/elements/1", Headers, <<"{">>),

  ct:comment("Missing parameters are reported"),
  None = #{},
  #{status_code := 400} =
    sr_test_utils:api_call(post, "/elements", Headers, None),
  #{status_code := 400} =
    sr_test_utils:api_call(put, "/elements/none", Headers, None),
  #{status_code := 400} =
    sr_test_utils:api_call(put, "/elements/1", Headers, None),
  #{status_code := 400} =
    sr_test_utils:api_call(patch, "/elements/1", Headers, None),

  NoVal = #{key => <<"noval">>},
  #{status_code := 400} =
    sr_test_utils:api_call(post, "/elements", Headers, NoVal),
  #{status_code := 400} =
    sr_test_utils:api_call(put, "/elements/noval", Headers, NoVal),
  #{status_code := 400} =
    sr_test_utils:api_call(put, "/elements/1", Headers, NoVal),
  #{status_code := 400} =
    sr_test_utils:api_call(patch, "/elements/1", Headers, NoVal),

  {comment, ""}.

-spec not_found(sr_test_utils:config()) -> {comment, string()}.
not_found(_Config) ->
  ct:comment("Not existing element is not found"),
  #{status_code := 404} = sr_test_utils:api_call(get, "/elements/notfound"),
  #{status_code := 404} = sr_test_utils:api_call(patch, "/elements/notfound"),
  #{status_code := 404} = sr_test_utils:api_call(delete, "/elements/notfound"),
  {comment, ""}.

-spec binary_id_conversion(sr_test_utils:config()) -> {comment, string()}.
binary_id_conversion(_Config) ->
  ct:comment("Different types of ids"),
  1 = sr_single_entity_handler:id_from_binding_internal(<<"1">>, integer),
  -1 = sr_single_entity_handler:id_from_binding_internal(<<"one">>, integer),
  <<"binary">> =
    sr_single_entity_handler:id_from_binding_internal(<<"binary">>, binary),
  "string" =
    sr_single_entity_handler:id_from_binding_internal(<<"string">>, string),
  {comment, ""}.

-spec location(sr_test_utils:config()) -> {comment, string()}.
location(_Config) ->
  Headers = #{<<"content-type">> => <<"application/json; charset=utf-8">>},

  ct:comment("Element 1 is created"),
  Key = <<"element1">>,
  #{status_code := 201, headers := ResponseHeaders} =
    sr_test_utils:api_call(
      post, "/elements", Headers,
      #{ key   => <<"element1">>
       , value => <<"val1">>
       }),
  ct:comment("and its location header is set correctly"),
  Location = proplists:get_value(<<"location">>, ResponseHeaders),
  Location = iolist_to_binary(["/elements/", Key]),

  {comment, ""}.
