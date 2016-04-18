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
     * An OrderBox displaying the tasks that are to be completed.
     */
    class TodoView : Gtk.Grid {
        
        private TaskStore task_store;
        private Filter filter;
        
        private Gtk.ScrolledWindow scroll_view;
        private OrderBox task_list;
        private BottomBar bottom_bar;
        
        public signal void task_selected (TXTTask? task);
        
        public TodoView () {
            this.orientation = Gtk.Orientation.VERTICAL;
            
            setup_widgets ();
            
            connect_signals ();
        }
        
        private void setup_widgets () {
            scroll_view = new Gtk.ScrolledWindow (null, null);
            task_list = new OrderBox ();
            bottom_bar = new BottomBar ();
            filter = new Filter ();
            
            task_list.set_filter_func (filter.filter);
            task_list.expand = true;
            task_list.vadjustment = scroll_view.vadjustment;
            
            scroll_view.add (task_list);
            this.add (scroll_view);
            this.add (bottom_bar);
        }
        
        /**
         * Binds a TaskStore to this.
         */
        public void set_store (TaskStore task_store) {
            this.task_store = task_store;
            bottom_bar.sort_clicked.connect (task_store.sort);
            task_store.link_clicked.connect (bottom_bar.set_search_string);
            task_list.bind_model (task_store);
        }
        
        private void connect_signals () {
            bottom_bar.search_changed.connect (filter.parse);
            filter.changed.connect (task_list.invalidate_filter);
            
            task_list.row_selected.connect ( (row) => {
                TXTTask? task = null;
                if (row != null) {
                    task = ((TaskRow) row).task;
                }
                task_selected (task);
            });
        }
        
        public override void show_all () {
            base.show_all ();
            
            // Select the first row on startup
            if (task_list.get_selected_row () == null) {
                task_list.select_row (task_list.get_nth_visible (0));   
            }
        }
        
    }
}
