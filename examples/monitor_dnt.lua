-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--[[
Monitor DNT header status

*Example Heka Configuration*

.. code-block:: ini

    [DNTUsage]
    type = "SandboxFilter"
    filename = "examples/monitor_dnt.lua"
    message_matcher = "Type == 'telemetry'"
    ticker_interval = 10
    preserve_data = true
        [DNTUsage.config]
        # Increment this if the format changes in a
        # backwards-incompatible way
        preservation_version = 1
        # Number of entries to keep in the circular buffer
        rows = 1440
        # Length of each bucket in the circular buffer
        sec_per_row = 300

--]]
_PRESERVATION_VERSION = read_config("preservation_version") or 0

require "circular_buffer"

-- Default to 2880 minute-long intervals
local rows = read_config("rows") or 2880
local sec_per_row = read_config("sec_per_row") or 60

-- Create a circular buffer with three columns. It must
-- be a global variable in order for 'preserve_data' to
-- have any effect.
c = circular_buffer.new(rows, 3, sec_per_row, true)

-- Set the header names for the columns
local ON  = c:set_header(1, "DNT On")
local OFF = c:set_header(2, "DNT Off")
local UNK = c:set_header(3, "DNT Unknown")

function process_message ()
    local ts = read_message("Timestamp")
    local item = read_message("Fields[DNT]")

    if item == "1" then
        c:add(ts, ON, 1)
    elseif item == "0" then
        c:add(ts, OFF, 1)
    else
        c:add(ts, UNK, 1)
    end

    return 0
end

function timer_event(ns)
    -- Inject the entire circular buffer
    inject_payload("cbuf", "DNT Status", c:format("cbuf"))

    -- Inject the cbuf delta (changes since last timer event)
    inject_payload("cbufd", "DNT Status", c:format("cbufd"))
end
