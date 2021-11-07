/* Copyright 2016-2019 Go For It! developers
*
* This file is part of Go For It!.
*
* Go For It! is free software: you can redistribute it
* and/or modify it under the terms of version 3 of the
* GNU General Public License as published by the Free Software Foundation.
*
* Go For It! is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with Go For It!. If not, see http://www.gnu.org/licenses/.
*/

public enum TaskStatus {
    NONE = 0,
    TIMER_ACTIVE = 0x01,
    TIMER_SELECTED = 0x02
}

/**
 * This class stores all task information.
 */
public class GOFI.TodoTask : GLib.Object {
    public virtual string description {
        public get {
            return _description;
        }
        public set {
            _description = value;
        }
    }
    string _description = "";

    public virtual bool valid {
        get {
            return description != "";
        }
    }

    private const int64 US_C = 1000000; // μs<->s conversion
    private static uint us_to_s (int64 us_val) {
        return (uint) ((us_val + 500000) / US_C);
    }

    /**
     * Total time spent working on the task using the timer in seconds.
     */
    [CCode (notify=false)]
    public uint timer_seconds {
        public get {
            return us_to_s (timer_value);
        }
        public set {
            timer_value = value * 1000000;
        }
    }

    /**
     * Total time spent working on the task using the timer in microseconds.
     */
    public virtual int64 timer_value {
        public get;
        public set;
        default = 0;
    }

    public virtual TaskStatus status {
        public get;
        public set;
        default = TaskStatus.NONE;
    }

    /**
     * Indication of the duration of the task in seconds.
     * (How long the user thinks the task should take)
     * This should be set to 0 if no indication is given.
     */
    public uint duration {
        public get;
        public set;
        default = 0;
    }

    public signal void invalidate ();

    public TodoTask (string line) {
        Object ();
        _description = line;
    }

    construct {}
}
