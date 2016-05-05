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
        
        public override string title {
            public get {
                return _title;
            }
            protected set {
                _title = value;
            }
        }
        private string _title;
        
        public override bool done {
            public get {
                return _done;
            }
            public set {
                _done = value;
            }
        }
        private bool _done;
        
        public bool valid {
            public get {
                return reference.valid ();
            }
        }
        
        public TXTTask (string title, bool done, Gtk.TreeRowReference reference) {
            base ();
            this._title = title;
            this._done = done;
            this.reference = reference;
        }
        
        public void set_title (string title) {
            this.title = title;
        }
        
    }
}
