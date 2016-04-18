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
        private Gtk.Label title_label;
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
        
        private void setup_widgets () {
            layout = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            check_button = new Gtk.CheckButton ();
            title_label = new Gtk.Label (null);
            drag_image = new Gtk.Image.from_icon_name (
                "view-list-symbolic", Gtk.IconSize.BUTTON
            );
            
            title_label.wrap = true;
            title_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
            title_label.width_request = 200;
            // Workaround for: "undefined symbol: gtk_label_set_xalign"
            ((Gtk.Misc) title_label).xalign = 0f;
            
            drag_image.expand = true;
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
        
        private void update () {
            string title = task.title;
            
            title = make_links (title, "+", "project:");
            title = make_links (title, "@", "context:");
            
            title_label.set_markup (title);
        }
    }
}
