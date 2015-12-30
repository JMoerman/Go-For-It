/* Copyright 2015 Manuel Kehl (mank319)
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

namespace GOFI.Todo {
    /**
     * A class for passing common task information.
     */
    public abstract class TodoTask : Object {
        
        public string title;
        public bool done;
        public int64 time_spend;
        
        public signal void changed ();
        
        public TodoTask (string title, bool done, int64 time_spend = 0) {
            this.title = title;
            this.done = done;
            this.time_spend = time_spend;
        }
    }
}
