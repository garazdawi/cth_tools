%%% @doc Common Test Framework functions handling test specifications.
%%%
%%% <p>This module creates a junit report of the test run if plugged in
%%% as a suite_callback.</p>

-module(cth_junit).

%% Suite Callbacks
-export([id/1, init/2]).

-export([pre_init_per_suite/3]).
-export([post_init_per_suite/4]).
-export([pre_end_per_suite/3]).
-export([post_end_per_suite/4]).

-export([pre_init_per_group/3]).
-export([post_init_per_group/4]).
-export([pre_end_per_group/3]).
-export([post_end_per_group/4]).

-export([pre_init_per_testcase/3]).
-export([post_end_per_testcase/4]).

-export([on_tc_fail/3]).

-export([terminate/1]).

-record(state, { filepath, curr_suite, curr_group = [], curr_tc, curr_log_dir,
		 test_cases = [],
		 test_suites = [] }).

-record(testcase, { classname, name, time, failure }).
-record(testsuite, { errors, failures, hostname, name, tests,
		     time, timestamp, id, package,
		     properties, testcases }).

id(Opts) ->
    filename:absname(proplists:get_value(path, Opts, "junit_report.xml")).

init(Path, _Opts) ->
    %dbg:tracer(),dbg:p(all,c),dbg:tpl(?MODULE,x),
    #state{ filepath = Path }.

pre_init_per_suite(Suite,Config,State) ->
    {Config, State#state{ curr_suite = Suite } }.

post_init_per_suite(_Suite,_Config, Result, State) ->
    {Result, add_tc(init_per_suite,Result,State)}.

pre_end_per_suite(_Suite,Config,State) -> {Config, State}.

post_end_per_suite(_Suite,_Config,Result,State) -> 
    NewState = add_tc(end_per_suite,Result,State),
    TCs = NewState#state.test_cases,
    Suite = get_suite(TCs),
    {Result, State#state{ test_cases = [], 
			  test_suites = [Suite | State#state.test_suites]}}.

pre_init_per_group(Group,Config,State) -> 
    {Config, State#state{ curr_group = [Group|State#state.curr_group]}}.

post_init_per_group(_Group,_Config,Result,State) -> 
    {Result, add_tc(init_per_group,Result,State)}.

pre_end_per_group(_Group,Config,State) -> {Config, State}.

post_end_per_group(_Group,_Config,Result,State) -> 
    NewState = add_tc(end_per_group, Result, State),
    {Result, NewState#state{ curr_group = tl(NewState#state.curr_group)}}.

pre_init_per_testcase(_TC,Config,State) -> {Config, State}.

post_end_per_testcase(TC,_Config,Result,State) -> 
    {Result, add_tc(TC,Result,State)}.

on_tc_fail(_TC, Res, State) ->
    TCs = State#state.test_cases,
    TC = hd(State#state.test_cases),
    NewTC = TC#testcase{ failure = 
			     lists:flatten(io_lib:format("~p",[Res])) },
    State#state{ test_cases = [NewTC | tl(TCs)]}.

add_tc(Func, Res, State) when is_atom(Func) ->
    add_tc(atom_to_list(Func), Res, State);
add_tc(Name, _Res, State = #state{ curr_suite = Suite,curr_group = Groups} ) ->
    ClassName = atom_to_list(Suite),
    PName = lists:flatten([ atom_to_list(Group) ++ "." || 
			  Group <- lists:reverse(Groups)]) ++ Name,
    State#state{ test_cases = [#testcase{ classname = ClassName, 
					  name = PName,
					  time = "0",
					  failure = passed }| State#state.test_cases]}.

get_suite(TCs) ->
    Total = length(TCs),
    Succ = length(lists:filter(fun(#testcase{ failure = F }) ->
				       F == passed
			       end,TCs)),
    Fail = Total - Succ,
    #testsuite{ errors = Fail, tests = Total, testcases = TCs }.
    
terminate(State) -> 
    {ok,D} = file:open(State#state.filepath,[write]),
    io:format(D, to_xml(State#state.test_suites), []),
    catch file:sync(D),
    catch file:close(D).

to_xml(#testcase{ classname = CL, name = N, time = T, failure = F}) ->
    ["<testcase classname=\"",CL,"\" name=\"",N,"\" time=\"",T,"\">",
     if
	 F == passed ->
	     [];
	 true ->
	     ["<failure message=\"Test ",N," in ",CL," failed!\" type=\"crash\">",
	      sanitize(F),"</failure>"]
     end,"</testcase>"];
to_xml(#testsuite{ errors = E, tests = T, testcases = Cases }) ->
    ["<testsuite errors=\"",integer_to_list(E),"\" tests=\"",integer_to_list(T),"\">",
     [to_xml(Case) || Case <- Cases],
     "</testsuite>"];
to_xml(TestSuites) when is_list(TestSuites) ->
    ["<testsuites>",[to_xml(TestSuite) || TestSuite <- TestSuites],"</testsuites>"].

sanitize([$>|T]) ->
    "&gt;" ++ sanitize(T);
sanitize([$<|T]) ->
    "&lt;" ++ sanitize(T);
sanitize([H|T]) ->
    [H|sanitize(T)];
sanitize([]) ->
    [].


example_xml() ->
    "<testsuites>"
	"<testsuite errors=\"1\" failures=\"1\" hostname=\"host\" name=\"suitename\" "
	"tests=\"3\" time=\"0.002\" timestamp=\"2010-09-21T14:21:05\" "
	"id=\"1\" package=\"pkg\">"
	"<properties>"
	"<property name=\"otp_ver\" value=\"R14B\"/>"
	"</properties>"
	"<testcase classname=\"test_SUITE\" name=\"test\" time=\"0.0001\"/>"
	"<testcase classname=\"test_SUITE\" name=\"test1\" time=\"0.0001\">"
	"<failure message=\"test_SUITE:test1 failed!\" type=\"crash\">"
	"Test info"
	"</failure>"
	"</testcase>"
	"<testcase classname=\"test_SUITE\" name=\"test2\" time=\"0.0001\">"
	"<error type=\"crash\">"
	"Error message!"
	"</error></testcase>"
	"<system-out/>"
	"<system-err/>" 
	"</testsuite>"
	"<testsuite errors=\"1\" failures=\"1\" hostname=\"host\" name=\"suitename2\" "
	"tests=\"3\" time=\"0.002\" timestamp=\"2010-09-21T14:21:05\" "
	"id=\"2\" package=\"akjdgaskjhg\">"
	"<properties>"
	"<property name=\"otp_ver\" value=\"R14B01\"/>"
	"</properties>"
	"<testcase classname=\"test1_SUITE\" name=\"test\" time=\"0.0001\"/>"
	"<testcase classname=\"test1_SUITE\" name=\"test1\" time=\"0.0001\">"
	"<failure message=\"test_SUITE1:test1 failed!\" type=\"crash\">"
	"Test info"
	"</failure>"
	"</testcase>"
	"<testcase classname=\"test1_SUITE\" name=\"test2\" time=\"0.0001\">"
	"<error type=\"crash\">"
	"Error message!"
	"</error></testcase>"
	"<system-out/>"
	"<system-err/>" 
	"</testsuite>"
	"</testsuites>".

%%% XML spec of junit report format
%% start = testsuites

%% property = element property {
%% attribute name {text},
%% attribute value {text}
%% }

%% properties = element properties {
%% property*
%% }

%% failure = element failure {
%% attribute message {text},
%% attribute type {text},
%% text
%% }

%% testcase = element testcase {
%% attribute classname {text},
%% attribute name {text},
%% attribute time {text},
%% failure?
%% }

%% testsuite = element testsuite {
%% attribute errors {xsd:integer},
%% attribute failures {xsd:integer},
%% attribute hostname {text},
%% attribute name {text},
%% attribute tests {xsd:integer},
%% attribute time {xsd:double},
%% attribute timestamp {xsd:dateTime},
%% attribute id {text},
%% attribute package {text},
%% properties,
%% testcase*,
%% element system-out {text},
%% element system-err {text}
%% }
%% }

%% testsuites = element testsuites {
%% testsuite*
%% }

