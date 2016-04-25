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
     * An OrderBox displaying the completed tasks.
     */
    class DoneView : Gtk.Grid {
        
        private TaskStore task_store;
        
        private Gtk.ScrolledWindow scroll_view;
        private OrderBox task_list;
        
        public DoneView () {
            this.orientation = Gtk.Orientation.VERTICAL;
            
            setup_widgets ();
        }
        
        /**
         * We need to make sure that task_list is freed, because it holds a 
         * reference to this: bind_model increases the ref_count of this because
         * widget_func is defined in this class.
         */
        public override void destroy () {
            base.destroy ();
            task_list = null;
        }
        
        private void setup_widgets () {
            scroll_view = new Gtk.ScrolledWindow (null, null);
            task_list = new OrderBox ();
            
            task_list.expand = true;
            task_list.vadjustment = scroll_view.vadjustment;
            
            scroll_view.add (task_list);
            this.add (scroll_view);
        }
        
        /**
         * Binds a TaskStore to this.
         */
        public void set_store (TaskStore task_store) {
            this.task_store = task_store;
            task_list.bind_model (task_store, widget_func);
        }
        
        private Gtk.Widget widget_func (Object item) {
            TaskRow row = new TaskRow ((TXTTask) item);
            row.show_all ();
            return row;
        }
    }
}
