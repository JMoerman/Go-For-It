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
    
    /**
     * A single row in a TodoView or DoneView.
     */
    class TaskRow : OrderBoxRow {
        
        private Gtk.Box layout;
        private Gtk.CheckButton check_button;
        private TaskLabel title_label;
        private Gtk.Image drag_image;
        
        private TXTTask _task;
        
        public signal void toggled ();
        public signal void link_clicked (string uri);
        
        public TXTTask task {
            public get {
                return _task;
            }
            private set {
                _task = value;
            }
        }
        
        public TaskRow (TXTTask task) {
            base ();
            _task = task;
            setup_widgets ();
            connect_signals ();
        }
        
        public void edit () {
            title_label.edit ();
        }
        
        public void abort_editing () {
            title_label.abort_editing ();
        }
        
        private void setup_widgets () {
            layout = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            check_button = new Gtk.CheckButton ();
            title_label = new TaskLabel (task.title);
            title_label.hexpand = true;
            drag_image = new Gtk.Image.from_icon_name (
                "view-list-symbolic", Gtk.IconSize.BUTTON
            );
            
            drag_image.halign = Gtk.Align.END;
            
            check_button.active = _task.done;
            
            update ();
            
            layout.add (check_button);
            layout.add (title_label);
            layout.add (drag_image);
            this.add (layout);
        }
        
        private void connect_signals () {
            check_button.toggled.connect ( () => {
                task.done = check_button.active;
                toggled ();
            });
            
            task.changed.connect (update);
            
            title_label.activate_link.connect ( (uri) => {
                link_clicked (uri);
                return true;
            });
            title_label.string_changed.connect ( () => {
                task.title = title_label.txt_string;
            });
        }
        
        private void update () {
            title_label.txt_string = task.title;
        }
    }
    
    /**
     * ...
     */
    class TaskLabel : Gtk.Stack {
        Gtk.Label label;
        Gtk.Entry entry;
        Gtk.Button button;
        
        private string markup_string;
        
        private string _txt_string;
        public string txt_string {
            public get {
                return _txt_string;
            }
            public set {
                _txt_string = value;
                update ();
            }
        }
        
        public signal bool activate_link (string uri);
        public signal void string_changed ();
        
        public TaskLabel (string txt_string) {
            _txt_string = txt_string;
            
            setup_widgets ();
        }
        
        public void setup_widgets () {
            label = new Gtk.Label(null);
            
            label.wrap = true;
            label.wrap_mode = Pango.WrapMode.WORD_CHAR;
            label.width_request = 200;
            // Workaround for: "undefined symbol: gtk_label_set_xalign"
            ((Gtk.Misc) label).xalign = 0f;
            
            update ();
            
            label.activate_link.connect ( (uri) => {
                return activate_link (uri);
            });
            add (label);
        }
        
        public void edit () {
            if (entry != null) {
                return;
            }
            stdout.printf ("editing\n");
            entry = new Gtk.Entry ();
            entry.can_focus = true;
            entry.text = _txt_string;
            add (entry);
            entry.show ();
            set_visible_child (entry);
            entry.grab_focus ();
            entry.activate.connect(stop_editing);
            entry.focus_out_event.connect ( (event) => {
                abort_editing ();
                return false;
            });
        }
        
        public void abort_editing () {
            if (entry != null) {
                set_visible_child (label);
                remove (entry);
                entry = null;
            }
        }
        
        private void stop_editing () {
            txt_string = entry.text;
            string_changed ();
            abort_editing ();
        }
        
        private void update () {
            gen_markup ();
            label.set_markup (markup_string);
        }
        
        private void gen_markup () {
            string markup;
            
            markup = make_links (_txt_string, "+", "project:");
            markup = make_links (markup, "@", "context:");
            
            markup_string = markup;
        }
        
        /**
         * Used to find projects and contexts and replace those parts with a 
         * link.
         * @param title the string to took for contexts or projects
         * @param delimiter prefix of the context or project (+/@)
         * @param prefix prefix of the new links
         */
        private string make_links (string title, string delimiter, 
                                   string prefix)
        {
            string parsed, remainder, val;
            
            parsed = "";
            remainder = title;
            
            while (remainder != null) {
                string[] string_parts = remainder.split (@" $delimiter", 2);
                parsed += string_parts[0];
                if (string_parts[1] != null) {
                    if (string_parts[1].get (0) == ' ') {
                        parsed += @" $delimiter";
                        remainder = string_parts[1];
                    } else {
                        string_parts = string_parts[1].split (" ", 2);
                        val = string_parts[0];
                        parsed += @" <a href=\"$prefix$val\" title=\"$val\">" +
                                  @"$delimiter$val</a>";
                        remainder = string_parts[1];
                        if (remainder != null) {
                            remainder = " " + remainder;
                        }
                    }
                } else {
                    remainder = null;
                }
            }
            return parsed;
        }
    }
}
