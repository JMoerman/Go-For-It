/* Copyright 2016 Go For It! developers
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

namespace GOFI {
    
    /**
     * A class for passing common task information.
     */
    public abstract class TodoTask : GLib.Object {
        
        private int64 _time_spent;
        
        /**
         * The title of this task.
         */
        public abstract string title {
            protected set;
            public get;
        }
        
        /**
         * Whether or not this task still needs to be completed.
         */
        public abstract bool done {
            public set;
            public get;
        }
        
        /**
         * The amount of time spent working on this task.
         */
        public virtual int64 time_spent {
            public set {
                _time_spent = value;
            }
            public get {
                return _time_spent;
            }
        }
        
        /**
         * The status_changed signal is emitted when the value of done is 
         * changed.
         */
        public signal void status_changed ();
        
        /**
         * Creates an empty TodoTask
         */
        public TodoTask () {
            _time_spent = 0;
        }
    }
}
