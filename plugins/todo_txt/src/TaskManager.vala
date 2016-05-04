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
     * This class is responsible for loading, saving and managing the user's tasks.
     * Therefore it offers methods for interacting with the set of tasks in all
     * lists. Editing specific tasks (e.g. removing, renaming) is to be done 
     * by addressing the corresponding TaskStore instance.
     */
    class TaskManager {
        private File todo_dir;
        private File todo_txt;
        private File done_txt;
        
        public TaskStore todo_store;
        public TaskStore done_store;
        
        public TXTTask active_task {
            public get {
                return _active_task;
            }
            public set {
                _active_task = value;
                todo_store.try_preserve (_active_task);
            }
        }
        private TXTTask _active_task;
        
        public signal void refreshed_todo_list ();
        public signal void refreshed_done_list ();
        public signal void active_task_completed ();
        public signal void active_task_invalid ();
        
        public TaskManager (SettingsManager settings) {
            todo_dir = File.new_for_path(settings.todo_txt_location);
            todo_txt = todo_dir.get_child ("todo.txt");
            done_txt = todo_dir.get_child ("done.txt");
            setup_stores ();
        }
        
        private void move_task (TXTTask task, TaskStore dest) {
            dest.add (task);
        }

        private bool transfer_tasks (TaskStore source, TaskStore destination, 
                                     bool done) 
        {
            var iter = source.iterator ();
            bool changed = false;

            while (iter.next ()) {
                TXTTask task = iter.get ();
                if (task.done == done) {
                    iter.remove ();
                    destination.add (task);
                    changed = true;
                }
            }
            
            return changed;
        }
        
        private void on_todo_store_refreshed () {
            todo_store.file_read_only = true;
            done_store.file_read_only = true;
            
            bool changed = transfer_tasks (todo_store, done_store, true);
            
            todo_store.file_read_only = false;
            done_store.file_read_only = false;
            
            if (changed) {
                todo_store.write ();
                done_store.write ();
            }
        }
        
        private void setup_stores () {
            todo_store = new TaskStore ();
            done_store = new TaskStore ();
            
            todo_store.txt_file = todo_txt;
            done_store.txt_file = done_txt;
            
            todo_store.read ();
            done_store.read ();
            
            on_todo_store_refreshed ();
            
            connect_store_signals ();
        }
        
        public void clear_done_store () {
            done_store.clear ();
        }
        
        private void connect_store_signals () {
            todo_store.task_status_changed.connect ((task) => {
                move_task (task, done_store);
                todo_store.remove_task (task);
                if (task == _active_task) {
                    active_task_completed ();
                }
            });
            done_store.task_status_changed.connect ((task) => {
                move_task (task, todo_store);
                done_store.remove_task (task);
            });
            todo_store.reset.connect (on_todo_store_refreshed);
            todo_store.preserving_failed.connect ( () => {
                active_task_invalid ();
            });
        }
    }
}
