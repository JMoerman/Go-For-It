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
     * TODO: add documentation here
     */
    class TaskStore : GLib.Object, OrderBoxModel {
        
        private Gee.BidirListIterator<TXTTask> iter;
        
        private Gee.LinkedList<TXTTask> tasks;
        
        private int size;
        
        public signal void task_removed (TXTTask task);
        public signal void task_status_changed (TXTTask task);
        public signal void task_data_changed ();
        public signal void changed ();
        public signal void link_clicked (string uri);
        
        public TaskStore (owned Gee.LinkedList<TXTTask> tasks) {
            set_tasks (tasks);
        }
        
        public void set_tasks (owned Gee.LinkedList<TXTTask> tasks) {
            this.tasks = tasks;
            
            foreach (TXTTask task in tasks) {
                connect_task_signals (task);
            }
            
            size = tasks.size;
            
            iter = tasks.bidir_list_iterator ();
            iter.next ();
            reset ();
            changed ();
        }
        
        /**
         * Returns a read only view of all tasks in this.
         */
        public Gee.List<TXTTask> get_tasks () {
            return tasks.read_only_view;
        }
        
        
        /**
         * Adds an item at the end.
         */
        public void add_task (TXTTask task) {
            insert (task, size);
        }
        
        /**
         * Inserts an item at the specified position.
         */
        public void insert (TXTTask task, int position) {
            tasks.insert (position, task);
            make_iter ();
            size++;
            item_added (position);
            
            connect_task_signals (task);
        }
        
        private void connect_task_signals (TXTTask task) {
            task.changed.connect (on_task_changed);
            task.status_changed_task.connect (on_status_changed);
        }
        
        private void disconnect_task_signals (TXTTask task) {
            task.changed.disconnect (on_task_changed);
            task.status_changed_task.disconnect (on_status_changed);
        }
        
        private void on_status_changed (TXTTask task) {
            task_status_changed (task);
            changed ();
        }
        
        private void on_task_changed () {
            task_data_changed ();
            changed ();
        }
        
        /**
         * Removes the supplied task from this.
         */
        public void remove_task (TXTTask task) {
            int index = tasks.index_of (task);
            remove_task_at (index);
        }
        
        /**
         * Removes a task from this.
         */
        public void remove_task_at (int pos) {
            TXTTask task = tasks.remove_at (pos);
            disconnect_task_signals (task);
            make_iter ();
            size--;
            
            task_removed (task);
            item_removed (pos);
            items_changed ();
            changed ();
        }
        
        public void clear () {
            tasks.clear ();
            size = 0;
            reset ();
            changed ();
        }
        
        private void make_iter () {
            iter = tasks.bidir_list_iterator ();
            iter.next ();
        }
        
        /**
         * Returns the number of items in this.
         */
        public int get_n_items () {
            return tasks.size;
        }
        
        /**
         * Moves an item in this.
         * @param pos1 original position of the item
         * @param pos2 new position of the item
         * @param sync Whether or not the OrderBox needs to be updated
         */
        public void move_item (int pos1, int pos2, bool sync) {
            if (pos1 == pos2) {
                return;
            }
            
            if (pos1 < pos2) {
                pos2--;
            }
            
            TXTTask task = tasks.remove_at (pos1);
            tasks.insert (pos2, task);
            item_moved (pos1, pos2, sync);
            changed ();
        }
        
        public void sort () {
            tasks.sort (sort_func);
            sorted ();
        }
        
        public OrderBoxRow get_row (int pos) {
            int iter_index = iter.index ();
            while (iter_index < pos && iter.has_next ()) {
                iter.next ();
                iter_index++;
            }
            while (iter_index > pos && iter.has_previous ()) {
                iter.previous ();
                iter_index--;
            }
            
            TaskRow row = new TaskRow (iter.get ());
            
            row.link_clicked.connect ( (uri) => {
                link_clicked (uri);
            });
            
            return row;
        }
        
        /**
         * Returns an OrderBoxSortFunc for sorting the OrderBox, or null.
         * Sorting rows with this function must place the rows in the same order
         * as the items in this.
         */
        public OrderBoxSortFunc? get_sort_func () {
            return (row1, row2) => {
                return sort_func (((TaskRow)row1).task, ((TaskRow)row2).task);
            };
        }
        
        private int sort_func (TXTTask task1, TXTTask task2) {
            if (task1.txt_priority < task2.txt_priority) {
                return 1;
            } else if (task1.txt_priority > task2.txt_priority) {
                return -1;
            } else {
                if (task1.title == task2.title) {
                    if (&task1 < &task2) {
                        return -1;
                    } else {
                        return 1;
                    }
                }
                if (task1.title < task2.title) {
                    return -1;
                }
                return 1;
            }
        }
    }
}
