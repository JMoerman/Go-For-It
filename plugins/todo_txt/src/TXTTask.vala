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

namespace GOFI.Plugins.TodoTXT {
    class TXTTask : GOFI.TodoTask {
        
        public GLib.DateTime? creation_date = null;
        public GLib.DateTime? completion_date = null;
        public char txt_priority;
        
        public signal void status_changed_task (TXTTask task);
        
        public TXTTask () {
            base ();
            txt_priority = 0;
        }
        
        public override void status_changed (bool done) {
            if (done) {
                completion_date = new GLib.DateTime.now_local ();
            } else {
                completion_date = null;
            }
            
            status_changed_task (this);
            
            base.status_changed (done);
        }
    }
}
