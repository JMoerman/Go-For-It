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

namespace GOFI.Plugins.Classic {
    public class TXTTask : GOFI.TodoTask {
        
        public Gtk.TreeRowReference reference;
        
        public TXTTask (string title, bool done, Gtk.TreeRowReference reference) {
            base ();
            this.title = title;
            this.done = done;
            this.reference = reference;
        }
        
        public override bool is_valid () {
            if (base.is_valid ()) {
                return reference.valid ();
            }
            return false;
        }
        
    }
}
