%% watcher.erl - a library for monitoring line oriented files
%%
%% Copyright (c) 2009, Hynek Schlawack <hs@ox.cx>
%% All rights reserved.

%% Redistribution and use in source and binary forms, with or without
%% modification, are permitted provided that the following conditions
%% are met:
%%
%%     * Redistributions of source code must retain the above
%%       copyright notice, this list of conditions and the following
%%       disclaimer.
%%     * Redistributions in binary form must reproduce the above
%%       copyright notice, this list of conditions and the following
%%       disclaimer in the documentation and/or other materials
%%       provided with the distribution.
%%
%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
%% "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
%% LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
%% FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
%% COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
%% INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
%% (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
%% SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
%% HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
%% STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
%% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
%% OF THE POSSIBILITY OF SUCH DAMAGE.

-module(watcher).
-vsn(1).
-author('Hynek Schlawack').
-created('Date: 2009/02/24').

-export([start/2, watch/2]).


-include_lib("kernel/include/file.hrl").


-define(DELAY, 1000).

%%----------------------------------------------------------------------
%% Function: start/2
%%
%% Purpose: Spawns watch/2 in a new process.
%% Args:    See watch/2.
%% Returns: The PID of the process.
%%----------------------------------------------------------------------
start(Name, Pid)  ->
    spawn(?MODULE, watch, [Name, Pid]).

%%----------------------------------------------------------------------
%% Function: watch/2
%%
%% Purpose: Watch a file and notify a PID about new lines ({line,
%%          "foo"}) or file rotations (file_rotated) -- ie. when the
%%          file has been replaced by a new one.
%% Args:    Name is a file name to watch
%%          Pid is the PID to notify
%% Returns: Doesn't return.
%%----------------------------------------------------------------------
watch(Name, Pid) ->
    {ok, F} = file:open(Name, read),
    loop(F, 0, Name, Pid).


loop(FOrig, PosOrig, Name, Pid) ->
    {F, Pos} = check_rotate(FOrig, PosOrig, Name, Pid),

    case io:get_line(F, '') of
	eof ->
	    timer:sleep(?DELAY),
	    loop(F, Pos, Name, Pid);
	E = {error, _Error} ->
	    throw(E);
	L ->
	    Pid ! {line, L},
	    loop(F, element(2, file:position(F, cur)), Name, Pid)
    end.

check_rotate(F, Pos, Name, Pid) ->
    Size = get_file_size(Name),
    if
	Pos > Size ->
	    Pid ! file_rotated,
	    file:close(F),
	    {element(2, file:open(Name, read)), 0};
	true ->
	    {F, Pos}
    end.
    

get_file_size(Name) ->
    case file:read_file_info(Name) of
	{error, enoent} ->
	    error_logger:warning_msg("File is gone. Waiting and retrying."),
	    timer:sleep(?DELAY),
	    get_file_size(Name);
	{error, X} ->
	    throw(X);
	{ok, X} ->
	    X#file_info.size
    end.
