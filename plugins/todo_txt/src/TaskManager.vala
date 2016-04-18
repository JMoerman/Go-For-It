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
        
        private Parser parser;
        private Writer writer;
        
        private File todo_dir;
        private File todo_txt;
        private File done_txt;
        
        public TaskStore todo_store;
        public TaskStore done_store;
        
        public TXTTask active_task;
        
        public signal void refreshed ();
        public signal void active_task_completed ();
        
        public TaskManager (SettingsManager settings) {
            parser = new Parser ();
            writer = new Writer ();
            todo_dir = File.new_for_path(settings.todo_txt_location);
            todo_txt = todo_dir.get_child ("todo.txt");
            done_txt = todo_dir.get_child ("done.txt");
            load ();
        }
        
        private void move_task (TXTTask task, TaskStore dest) {
            dest.add_task (task);
        }
        
        private bool transfer_tasks (Gee.List<TXTTask> todo_list, 
                                     Gee.List<TXTTask> done_list) 
        {
            Gee.ListIterator<TXTTask> iter = todo_list.list_iterator ();
            bool changed = false;

            while (iter.next ()) {
                TXTTask task = iter.get ();
                if (task.done) {
                    iter.remove ();
                    done_list.add (task);
                    changed = true;
                }
            }
            
            return changed;
        }
        
        public void refresh () {
            load ();
            refreshed ();
        }
        
        public void load () {
            Gee.LinkedList<TXTTask> todo_list = new Gee.LinkedList<TXTTask> ();
            Gee.LinkedList<TXTTask> done_list = new Gee.LinkedList<TXTTask> ();
            
            parser.read (todo_txt, todo_list);
            parser.read (done_txt, done_list);
            
            bool changed = transfer_tasks (todo_list, done_list);
            
            todo_store = new TaskStore (todo_list);
            done_store = new TaskStore (done_list);
            
            if (changed) {
                save ();
            }
            
            connect_store_signals ();
        }
        
        private void connect_store_signals () {
            todo_store.task_status_changed.connect ((task) => {
                if (task == active_task) {
                    active_task_completed ();
                }
                move_task (task, done_store);
                todo_store.remove_task (task);
            });
            done_store.task_status_changed.connect ((task) => {
                move_task (task, todo_store);
                done_store.remove_task (task);
            });
            todo_store.changed.connect ( () => {
                save_store (false);
            });
            done_store.changed.connect ( () => {
                save_store (true);
            });
        }
        
        public void save_store (bool done) {
            if (done) {
                writer.write (done_txt, done_store.get_tasks ());
            } else {
                writer.write (todo_txt, todo_store.get_tasks ());
            }
        }
        
        public void save () {
            save_store (true);
            save_store (false);
        }
    }
}
