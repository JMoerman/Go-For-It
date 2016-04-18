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
     * A widget where the user can perform search actions, sort the list and add
     * new tasks.
     */
    class BottomBar : Gtk.Box {
        
        private Gtk.Revealer revealer;
        private Gtk.SearchEntry search_entry;
        
        private Gtk.ActionBar bar;
        
        private Gtk.Button search_button;
        private Gtk.Button sort_button;
        private Gtk.Button add_button;
        
        public signal void search_changed (string search_string);
        public signal void add_clicked ();
        public signal void sort_clicked ();
        
        public BottomBar () {
            this.orientation = Gtk.Orientation.VERTICAL;
            this.spacing = 0;
            
            setup_widgets ();
            
            connect_signals ();
        }
        
        private void setup_widgets () {
            revealer = new Gtk.Revealer ();
            search_entry = new Gtk.SearchEntry ();
            bar = new Gtk.ActionBar ();
            
            search_button = new Gtk.Button.from_icon_name (
                "edit-find", 
                Gtk.IconSize.SMALL_TOOLBAR
            );
            add_button = new Gtk.Button.from_icon_name (
                "list-add-symbolic", 
                Gtk.IconSize.SMALL_TOOLBAR
            );
            sort_button = new Gtk.Button.from_icon_name (
                "view-sort-ascending", // TODO: find a better icon for this
                Gtk.IconSize.SMALL_TOOLBAR
            );
            
            revealer.add (search_entry);
            
            bar.pack_start (search_button);
            bar.pack_start (sort_button);
            bar.pack_end (add_button);
            
            this.add (revealer);
            this.add (bar);
        }
        
        private void connect_signals () {
            search_button.clicked.connect (toggle_revealer);
            add_button.clicked.connect ( () => {
                add_clicked ();
            });
            sort_button.clicked.connect ( () => {
                sort_clicked ();
            });
            search_entry.search_changed.connect ( () => {
                search_changed (search_entry.text);
            });
        }
        
        public void toggle_revealer () {
            if (revealer.reveal_child) {
                revealer.set_reveal_child(false);
            } else {
                revealer.set_reveal_child(true);
                search_entry.grab_focus ();
            }
        }
        
        public void set_search_string (string search_string) {
            search_entry.text = search_string;
        }
        
    }
}
