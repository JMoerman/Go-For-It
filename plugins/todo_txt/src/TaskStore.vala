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
        private bool need_new_iter = true;
        internal uint external_iters = 0;
        
        private Gee.LinkedList<TXTTask> tasks;
        private TXTTask to_preserve = null;
        
        private FileMonitor monitor;
        
        private bool reading;
        private bool needs_refresh;
        
        private string etag = "";
        
        private File file;
        public File? txt_file {
            public get {
                return file;
            }
            public set {
                file = value;
                stop_monitoring ();
                start_monitoring ();
            }
        }
        
        private bool _file_read_only;
        public bool file_read_only {
            public get {
                return _file_read_only;
            }
            public set {
                _file_read_only = value;
            }
        }
        
        public signal void task_removed (TXTTask task);
        public signal void task_status_changed (TXTTask task);
        public signal void task_data_changed ();
        public signal void changed ();
        public signal void preserving_failed ();
        
        /**
         * 
         */
        public TaskStore () {
            tasks = new Gee.LinkedList<TXTTask> ();
            
            reading = false;
            needs_refresh = false;
        }
        
        /**
         * 
         */
        public void try_preserve (TXTTask? task) {
            to_preserve = task;
        }
        
        /**
         * 
         */
        public void set_tasks (owned Gee.LinkedList<TXTTask> tasks) {
            this.tasks = tasks;
            
            foreach (TXTTask task in tasks) {
                connect_task_signals (task);
            }
            
            iter = tasks.bidir_list_iterator ();
            iter.next ();
            reset ();
            changed ();
        }
        
        /**
         * 
         */
        public TaskStoreIterator iterator () {
            need_new_iter = true;
            return new TaskStoreIterator (this, tasks);
        }
        
        /**
         * Adds an item at the end.
         */
        public void add (TXTTask task) {
            insert (task, tasks.size);
        }
        
        /**
         * Inserts an item at the specified position.
         */
        public void insert (TXTTask task, int position) {
            tasks.insert (position, task);
            need_new_iter = true;
            item_added (position);
            
            connect_task_signals (task);
        }
        
        private void connect_task_signals (TXTTask task) {
            task.changed.connect (on_task_changed);
            task.status_changed.connect (on_status_changed);
            task.title_changed.connect (on_task_title_changed);
        }
        
        private void disconnect_task_signals (TXTTask task) {
            task.changed.disconnect (on_task_changed);
            task.status_changed.disconnect (on_status_changed);
            task.title_changed.disconnect (on_task_title_changed);
        }
        
        private void on_task_title_changed (TodoTask task, string title) {
            if (!task.is_valid ()) {
                remove_task ((TXTTask)task);
            }
        }
        
        private void on_change () {
            changed ();
            if (!_file_read_only) {
                write ();
            }
        }
        
        private void on_status_changed (TodoTask task, bool done) {
            stdout.printf ("%s\n", task.title);
            task_status_changed ((TXTTask)task);
            on_change ();
        }
        
        private void on_task_changed () {
            task_data_changed ();
            on_change ();
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
            need_new_iter = true;
            disconnect_task_signals (task);
            
            task_removed (task);
            item_removed (pos);
            items_changed ();
            on_change ();
        }
        
        public void clear () {
            foreach (TXTTask task in tasks) {
                disconnect_task_signals (task);
            }
            
            tasks.clear ();
            need_new_iter = true;
            reset ();
            items_changed ();
            on_change ();
        }
        
        private void fix_iter () {
            if (need_new_iter || !iter.valid) {
                iter = tasks.bidir_list_iterator ();
                iter.next ();
                need_new_iter = false;
            }
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
            on_change ();
        }
        
        public void sort () {
            tasks.sort (sort_func);
            sorted ();
        }
        
        public Object get_item (int pos) {
            if (external_iters > 0) {
                fix_iter ();
                int iter_index = iter.index ();
                while (iter_index < pos && iter.has_next ()) {
                    iter.next ();
                    iter_index++;
                }
                while (iter_index > pos && iter.has_previous ()) {
                    iter.previous ();
                    iter_index--;
                }
                
                return iter.get ();
            }
            return tasks.get (pos);
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
        
        /*
         * File monitoring
         *--------------------------------------------------------------------*/
         
        /**
         * 
         */
        private void start_monitoring () {
            if (file != null) {
                try {
                    monitor = file.monitor (FileMonitorFlags.NONE, null);
                    monitor.changed.connect ((src, dest, event) => {
                        if (event == FileMonitorEvent.CHANGES_DONE_HINT) {
                            if (!needs_refresh) {
                                needs_refresh = true;
                                GLib.Timeout.add(
                                    50, auto_refresh, GLib.Priority.DEFAULT_IDLE
                                );
                            }
                        }
                    });
                } catch (Error e) {
                    
                }
            }
        }
        
        /**
         * 
         */
        private void stop_monitoring () {
            if (monitor != null) {
                monitor.cancel ();
            }
        }
        
        private void gen_etag () {
            FileInfo info;
            
            if (file != null) {
                try {
                    info = file.query_info (GLib.FileAttribute.ETAG_VALUE, 0);
                    etag = info.get_etag ();
                } catch (Error e) {
                    error (e.message);
                }
            }
        }
        
        private bool check_etag () {
            string old_etag = etag;
            
            gen_etag ();
            
            return (old_etag == etag);
        }
        
        private bool auto_refresh () {
            if (!check_etag ()) {
                read ();
            }
            
            needs_refresh = false;
            return false;
        }
        
        /*
         * Reading from a .txt file
         *--------------------------------------------------------------------*/
        
        /**
         * @param tasks list containing the parsed tasks
         */
        public void read () {
            
            stdout.printf ("reading file\n");
            
            reading = true;
            Gee.LinkedList<TXTTask> new_tasks = new Gee.LinkedList<TXTTask> ();
            if (!file.query_exists()) {
                DirUtils.create_with_parents (
                    file.get_parent().get_path (), 0700
                );
                try {
                    file.create (FileCreateFlags.NONE); 
                } catch (Error e) {
                    error ("%s", e.message);
                }
                return;
            }
            
            // Read data from todo.txt or done.txt file
            try {
                var stream_in = new DataInputStream (file.read ());
                string line;
                TXTTask to_preserve = this.to_preserve;
                
                while ((line = stream_in.read_line (null)) != null) {
                    line = line.strip ();
                    int length = line.length;
                    if (length > 0) {
                        if (line.get (length - 1) == 13) {
                            if (length == 1) {
                                continue;
                            }
                            line = line.slice (0, length - 1);
                        }
                    } else {
                        continue;
                    }
                    if (line.strip().length > 0) {
                        TXTTask task = new TXTTask.from_txt (line);
                        if (to_preserve != null) {
                            if (task.equals(to_preserve)) {
                                task = to_preserve;
                                to_preserve = null;
                            }
                        }
                        new_tasks.add (task);
                    }
                }
            } catch (Error e) {
                error ("%s", e.message);
            }
            gen_etag ();
            set_tasks (new_tasks);
            reading = false;
            if (to_preserve != null) {
                preserving_failed ();
            }
        }
        
        /*
         * Writing to a txt file
         *--------------------------------------------------------------------*/
        
        /**
         * @param tasks list of tasks that needs to be written to a todo.txt
         * file.
         */
        public void write () {
            
            stdout.printf ("writing file\n");
            
            if (reading || _file_read_only) {
                return;
            }
            try {
                var file_io_stream = 
                    file.replace_readwrite (null, true, FileCreateFlags.NONE);
                var stream_out = 
                    new DataOutputStream (file_io_stream.output_stream);
                
                foreach (TXTTask task in tasks) {
                    stream_out.put_string (task.to_txt () + "\n");
                }
            } catch (Error e) {
                error ("%s", e.message);
            }
            gen_etag ();
        }
    }
    
    public class TaskStoreIterator {
        private Gee.BidirListIterator<TXTTask> gee_iter;
        private TaskStore store;
        
        public bool read_only {
            public get {
                return gee_iter.read_only;
            }
        }
        
        private bool _valid;
        
        public bool valid {
            public get {
                return _valid && gee_iter.valid;
            }
        }
        
        internal TaskStoreIterator (TaskStore store, 
                                    Gee.LinkedList<TXTTask> tasks)
        {
            this.store = store;
            this.gee_iter = tasks.bidir_list_iterator ();
            
            store.external_iters++;
            
            _valid = true;
            
            store.reset.connect (() => {
                _valid = false;
            });
        }
        
        ~TaskStoreIterator () {
            store.external_iters--;
        }
        
        public int index () {
            return gee_iter.index ();
        }
        
        public bool has_next () {
            return gee_iter.has_next ();
        }
        
        public bool next () {
            return gee_iter.next ();
        }
        
        public bool has_previous () {
            return gee_iter.previous ();
        }
        
        public bool previous () {
            return gee_iter.previous ();
        }
        
        public bool first () {
            return gee_iter.first ();
        }
        
        public bool last () {
            return gee_iter.last ();
        }
        
        public TXTTask @get () {
            return gee_iter.@get ();
        }
        
        public void add (TXTTask task) {
            assert (valid);
            if (read_only) {
                return;
            }
            
            int index = gee_iter.index ();
            
            gee_iter.add (task);
            store.item_added (index + 1);
        }
        
        public void remove () {
            assert (valid);
            if (read_only) {
                return;
            }
            
            int index = gee_iter.index ();
            
            gee_iter.remove ();
            store.item_removed (index);
        }
        
        public void insert (TXTTask task) {
            assert (valid);
            if (read_only) {
                return;
            }
            
            int index = gee_iter.index ();
            
            gee_iter.insert (task);
            store.item_added (index);
        }
    }
}
