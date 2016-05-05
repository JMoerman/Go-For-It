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
        
        private Gtk.Revealer search_revealer;
        private Gtk.SearchEntry search_entry;
        private Gtk.Revealer add_revealer;
        private Gtk.Entry add_entry;
        
        private Gtk.ActionBar bar;
        
        private Gtk.Button search_button;
        private Gtk.Button sort_button;
        private Gtk.Button add_button;
        
        private bool add_new;
        
        /* Signals */
        public signal void add_new_task (string task);
        public signal void search_changed (string search_string);
        public signal void sort_clicked ();
        
        public BottomBar (bool add_new = false) {
            this.orientation = Gtk.Orientation.VERTICAL;
            this.spacing = 0;
            this.add_new = add_new;
            
            setup_widgets ();
            
            connect_signals ();
        }
        
        private void setup_widgets () {
            search_revealer = new Gtk.Revealer ();
            search_entry = new Gtk.SearchEntry ();
            bar = new Gtk.ActionBar ();
            
            search_button = new Gtk.Button.from_icon_name (
                "edit-find", 
                Gtk.IconSize.SMALL_TOOLBAR
            );
            
            sort_button = new Gtk.Button.from_icon_name (
                "view-sort-ascending", // TODO: find a better icon for this
                Gtk.IconSize.SMALL_TOOLBAR
            );
            
            search_revealer.add (search_entry);
            
            bar.pack_start (search_button);
            bar.pack_start (sort_button);
            
            if (add_new) {
                setup_add_widgets ();
            }
            
            this.add (search_revealer);
            this.add (bar);
        }
        
        private void setup_add_widgets () {
            add_revealer = new Gtk.Revealer ();
            add_entry = new Gtk.Entry ();
            
            add_button = new Gtk.Button.from_icon_name (
                "list-add-symbolic", 
                Gtk.IconSize.SMALL_TOOLBAR
            );
            
            add_entry.placeholder_text = _("Add new task...");

            add_entry.set_icon_from_icon_name (
                Gtk.EntryIconPosition.PRIMARY, "list-add-symbolic");
            
            add_button.clicked.connect (toggle_add_revealer);
            
            add_entry.activate.connect ( () => {
                add_new_task (add_entry.text);
                add_entry.text = "";
                toggle_add_revealer ();
            });
            
            add_revealer.add (add_entry);
            
            bar.pack_end (add_button);
            this.add (add_revealer);
        }
        
        private void connect_signals () {
            search_button.clicked.connect (toggle_search_revealer);
            
            sort_button.clicked.connect ( () => {
                sort_clicked ();
            });
            search_entry.search_changed.connect ( () => {
                search_changed (search_entry.text);
            });
        }
        
        public void toggle_search_revealer () {
            if (search_revealer.reveal_child) {
                search_revealer.set_reveal_child (false);
            } else {
                if (add_new) {
                    add_revealer.set_reveal_child (false);
                }
                search_revealer.set_reveal_child (true);
                search_entry.grab_focus ();
            }
        }
        
        private void toggle_add_revealer () {
            if (add_revealer.reveal_child) {
                add_revealer.set_reveal_child (false);
            } else {
                search_revealer.set_reveal_child (false);
                add_revealer.set_reveal_child (true);
                add_entry.grab_focus ();
            }
        }
        
        public void set_search_string (string search_string) {
            search_entry.text = search_string;
        }
        
    }
}
