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
    
    /**
     * This class is responsible for loading, saving and managing the user's tasks.
     * Therefore it offers methods for interacting with the set of tasks in all
     * lists. Editing specific tasks (e.g. removing, renaming) is to be done 
     * by addressing the corresponding TaskStore instance.
     */
    public class TaskManager {
        private SettingsManager settings;
        // The user's todo.txt related files
        private File todo_txt_dir;
        private File todo_txt;
        private File done_txt;
        public TaskStore todo_store;
        public TaskStore done_store;
        private FileMonitor monitor;
        private TXTTask timer_task;
        
        public bool refreshing {
            public get;
            private set;
        }
            
        string[] default_todos = {
            "Choose Todo.txt folder via \"Settings\"",
            "Spread the word about \"Go For It!\"",
            "Consider a donation to help the project",
            "Consider contributing to the project"
        };
        
        public signal void timer_task_completed ();
        public signal void refreshed ();
        
        public TaskManager (SettingsManager settings) {
            this.settings = settings;
            refreshing = false;
            
            // Initialize TaskStores
            todo_store = new TaskStore (false);
            done_store = new TaskStore (true);
            
            connect_store_signals ();
            load_task_stores ();
            
            setup_monitor ();
            
            /* Signal processing */
            settings.todo_txt_location_changed.connect (load_task_stores);
            
            // Move done tasks off the todo list on startup
            auto_transfer_tasks();
        }
        
        public void set_timer_task (TXTTask? timer_task) {
            this.timer_task = timer_task;
        }
        
        /**
         * To be called when adding a new (undone) task.
         */
        public void add_new_task (string task) {
            todo_store.add_task (task);
        }
        
        public void mark_task_done (GOFI.TodoTask task) {
            Gtk.TreeRowReference reference = ((TXTTask)task).reference;
            if (reference.valid ()) {
                // Get Gtk.TreeIterator from reference
                var path = reference.get_path ();
                Gtk.TreeIter iter;
                todo_store.get_iter (out iter, path);
                // Remove task from the todo lists
                transfer_task (iter, todo_store, done_store);
            }
        }
        
        /** 
         * Transfers a task from one TaskStore to another.
         */
        private void transfer_task (Gtk.TreeIter iter,
                TaskStore source, TaskStore destination ) {
            Value description;
            source.get_value (iter, 1, out description);
            destination.add_task ((string) description);
            source.remove_task (iter);
        }
        
        /**
         * Cleans the todo list by transfering all done tasks to the done list.
         */
        private void auto_transfer_tasks () {
            Gtk.TreeIter iter;
            // Iterate through TaskStore
            for (bool next = todo_store.get_iter_first (out iter); next;
                        next = todo_store.iter_next (ref iter)) {
                Value out1;
                todo_store.get_value (iter, 0, out out1);
                bool done = (bool) out1;
                
                if (done) {
                    transfer_task (iter, todo_store, done_store);
                }
            }
        }
        
        /**
         * Deletes all task on the "Done" list
         */
        public void clear_done_store () {
            done_store.clear ();
        }
        
        /**
         * Reloads all tasks.
         */
        public void refresh () {
            // Prevent unnecessary updates
            refreshing = true;
            
            load_tasks ();
            // Some tasks may have been marked as done by other applications.
            auto_transfer_tasks ();
            refreshed ();
            
            refreshing = false;
        }
        
        /**
         * Attempts to assign a new TreeRowReference to the task used by the 
         * TaskTimer.
         */
        public bool fix_task () {
            Gtk.TreeIter iter;
            if (!todo_store.get_iter_first (out iter)) {
                return false;
            }
            string description;
            do {
                todo_store.get (iter, 1, out description, -1);
                if (description == timer_task.title) {
                    var path = todo_store.get_path (iter);
                    var reference = new Gtk.TreeRowReference(todo_store, path);
                    timer_task.reference = reference;
                    return true;
                }
            } while (todo_store.iter_next (ref iter));
            return false;
        }
        
        private bool compare_tasks (Gtk.TreeIter iter) {
            if (timer_task == null) {
                return false;
            }
            Gtk.TreePath? iter_path = todo_store.get_path (iter);
            Gtk.TreePath? curr_path = timer_task.reference.get_path();
            if (iter_path == null || curr_path == null) {
                return false;
            }
            string iter_path_str = iter_path.to_string ();
            string curr_path_str = curr_path.to_string ();
            return (iter_path_str == curr_path_str);
        }
        
        private void check_timer_task (Gtk.TreeIter iter) {
            if (compare_tasks (iter)) {
                string description;
                todo_store.get (iter, 1, out description, -1);
                timer_task.set_title (description);
            }
        }
        
        private void check_timer_task_completed (Gtk.TreeIter iter) {
            if (compare_tasks (iter)) {
                timer_task_completed ();
            }
        }
        
        private void connect_store_signals () {
            // Save data, as soon as something has changed
            todo_store.task_data_changed.connect (save_tasks);
            done_store.task_data_changed.connect (save_tasks);

            // Move task from one list to another, if done or undone
            todo_store.task_done_changed.connect (task_done_handler);
            done_store.task_done_changed.connect (task_done_handler);
            
            // update timer_task to reflect the changes
            todo_store.task_name_changed.connect (check_timer_task);
        }
        
        private void load_task_stores () {
            stdout.printf("load_task_stores\n");
            todo_txt_dir = File.new_for_path(settings.todo_txt_location);
            todo_txt = todo_txt_dir.get_child ("todo.txt");
            done_txt = todo_txt_dir.get_child ("done.txt");
            
            load_tasks ();
        }

        private void task_done_handler (TaskStore source, Gtk.TreeIter iter) {
            if (source == todo_store) {
                check_timer_task_completed (iter);
                transfer_task (iter, todo_store, done_store);
            } else if (source == done_store) {
                transfer_task (iter, done_store, todo_store);
            }
        }
        
        private void load_tasks () {
            // prevent writing to the file while clearing or loading
            todo_store.task_data_changed.disconnect (save_tasks);
            done_store.task_data_changed.disconnect (save_tasks);
            
            todo_store.clear ();
            done_store.clear ();
            read_task_file (this.todo_store, this.todo_txt);
            read_task_file (this.done_store, this.done_txt);
            
            if (settings.first_start) {
                // Iterate in reverse order because todos are added to position 0
                for (int i = default_todos.length - 1;
                     i >= 0;
                     i--)
                {
                    todo_store.add_task(default_todos[i], 0);
                }
                settings.first_start = false;
            }
            
            todo_store.task_data_changed.connect (save_tasks);
            done_store.task_data_changed.connect (save_tasks);
        }
        
        private void save_tasks () {
            // Prevent monitor updates while saving
            monitor.cancel ();
            
            write_task_file (this.todo_store, this.todo_txt);
            write_task_file (this.done_store, this.done_txt);
            
            // setting up a new FileMonitor to resume monitoring the file
            setup_monitor ();
        }
        
        private void setup_monitor () {
            try {
                monitor = todo_txt_dir.monitor_directory (FileMonitorFlags.NONE, null);
            
                monitor.changed.connect ((src, dest, event) => {
                    if (event == FileMonitorEvent.CHANGES_DONE_HINT) {
                        refresh();
                    }
                });
            } catch (Error e) {
                error ("%s", e.message);
            }
        }
        
        /**
         * Reads tasks from a Todo.txt formatted file.
         */
        private void read_task_file (TaskStore store, File file) {
            // Create file and return if it does not exist
            if (!file.query_exists()) {
                DirUtils.create_with_parents (todo_txt_dir.get_path (), 0700);
                try {
                    file.create (FileCreateFlags.NONE); 
                } catch (Error e) {
                    error ("%s", e.message);
                }
                return;
            }
            
            // Read data from todo.txt and done.txt files
            try {
                var stream_in = new DataInputStream (file.read ());
                string line;
                
                while ((line = stream_in.read_line (null)) != null) {
                    // Removing carriage return at the end of a task and
                    // skipping empty lines
                    int length = line.length;
                    if (length > 0) {
                        if (line.get_char (length - 1) == 13) {
                            if (length == 1) {
                                continue;
                            }
                            line = line.slice (0, length - 1);
                        }
                    } else {
                        continue;
                    }

                    // Todo.txt notation: completed tasks start with an "x "
                    bool done = line.has_prefix ("x ");
                    
                    if (done) {
                        // Remove "x " from displayed string
                        line = line.split ("x ", 2)[1];
                    }
                    
                    store.add_initial_task (line, done);
                }
            } catch (Error e) {
                error ("%s", e.message);
            }
        }
        
        /**
         * Saves tasks to a Todo.txt formatted file.
         */
        private void write_task_file (TaskStore store, File file) {
            try {
                /*var stream_out = new DataOutputStream (
                    file.create (FileCreateFlags.REPLACE_DESTINATION));*/
                var file_io_stream = 
                    file.replace_readwrite (null, true, FileCreateFlags.NONE);
                var stream_out = 
                    new DataOutputStream (file_io_stream.output_stream);
                
                Gtk.TreeIter iter;
                // Iterate through the TaskStore
                for (bool next = store.get_iter_first (out iter); next;
                        next = store.iter_next (ref iter)) {
                    // Get data out of store
                    Value done, text;
                    store.get_value (iter, 0, out done);
                    store.get_value (iter, 1, out text);
                    
                    if ((bool) done) {
                        text = "x " + (string) text;
                    }
                    
                    stream_out.put_string ((string) text + "\n");
                }
            } catch (Error e) {
                error ("%s", e.message);
            }
        }
    }
}
