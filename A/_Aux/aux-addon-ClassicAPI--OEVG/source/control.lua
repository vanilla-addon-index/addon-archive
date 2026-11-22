module 'aux'

local T = require 'T'

local event_frame = CreateFrame('Frame', 'AuxThreadingFrame')

local listeners, threads = T.acquire(), T.acquire()
local listener_counts = T.acquire()
local listeners_dirty

local thread_id
function M.thread_id() return thread_id end

function handle.LOAD()
	event_frame:SetScript('OnEvent', EVENT)
end

local function cleanup_listeners()
	if not listeners_dirty then return end
	for id, listener in listeners do
		if listener.killed then
			listeners[id] = nil
		end
	end
	listeners_dirty = nil
end

function EVENT()
	for _, listener in listeners do
		if not listener.killed and event == listener.event then
			listener.cb(listener.kill)
		end
	end
	cleanup_listeners()
end

do
	function UPDATE()
		cleanup_listeners()
		for id, thread in threads do
			if thread.killed or not thread.k then
				threads[id] = nil
				if not next(threads) then -- Disable threading task so it doesn't consume resources doing nothing
					event_frame:SetScript('OnUpdate', nil)
				end
			else
				local k = thread.k
				thread.k = nil
				thread_id = id
				k()
				thread_id = nil
			end
		end
	end
end

do
	local id = 0
	function unique_id()
		id = id + 1
		return id
	end
end

function M.kill_listener(listener_id)
	local listener = listeners[listener_id]
	if listener and not listener.killed then
		listener.killed = true
		listeners_dirty = true

		local listener_event = listener.event
		listener_counts[listener_event] = (listener_counts[listener_event] or 1) - 1
		if listener_counts[listener_event] <= 0 then
			listener_counts[listener_event] = nil
			event_frame:UnregisterEvent(listener_event)
		end
	end
end

function M.kill_thread(thread_id)
	local thread = threads[thread_id]
	if thread then
		thread.killed = true
	end
end

function M.event_listener(event, cb)
	local listener_id = unique_id()
	listeners[listener_id] = T.map(
		'event', event,
		'cb', cb,
		'kill', T.vararg-function(arg) if getn(arg) == 0 or arg[1] then kill_listener(listener_id) end end
	)
	if not listener_counts[event] then
		event_frame:RegisterEvent(event)
		listener_counts[event] = 1
	else
		listener_counts[event] = listener_counts[event] + 1
	end
	return listener_id
end

function M.on_next_event(event, callback)
	event_listener(event, function(kill) callback(); kill() end)
end

do
	local mt = {
		__call = function(self)
			T.temp(self)
			return self.f(unpack(self))
		end,
	}

	M.thread = T.vararg-function(arg)
		T.static(arg)
		arg.f = tremove(arg, 1)
		local thread_id = unique_id()
		threads[thread_id] = T.map('k', setmetatable(arg, mt))
		if event_frame:GetScript("OnUpdate") == nil then -- Spin up threading if it was turned off
			event_frame:SetScript('OnUpdate', UPDATE)
		end
		return thread_id
	end

	M.wait = T.vararg-function(arg)
		T.static(arg)
		arg.f = tremove(arg, 1)
		threads[thread_id].k = setmetatable(arg, mt)
	end
end

M.when = T.vararg-function(arg)
	local c = tremove(arg, 1)
	local k = tremove(arg, 1)
	if c() then
		return k(unpack(arg))
	else
		return wait(when, c, k, unpack(arg))
	end
end
