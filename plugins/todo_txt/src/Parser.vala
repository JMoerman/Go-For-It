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
     * A class for reading from a .txt file.
     */
    class Parser : Object {
        
        /**
         * @param tasks list containing the parsed tasks
         */
        public void read (File file, Gee.List<TXTTask> tasks) {
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
                
                while ((line = stream_in.read_line (null)) != null) {
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
                        TXTTask task;
                        task = parse_line (line);
                        tasks.add (task);
                    }
                }
            } catch (Error e) {
                error ("%s", e.message);
            }
        }
        
        /**
         * Parses a single line from the todo.txt file.
         */
        private TXTTask parse_line (string todo_line) {
            TXTTask task = new TXTTask ();
            string line = todo_line;
            
            // Todo.txt notation: completed tasks start with an "x "
            bool done = line.has_prefix ("x ");
            
            task.done = done;
                
            if (done) {
                // Remove "x " from displayed string
                line = line.split ("x ", 2)[1];
                task.completion_date = parse_date (ref line);
            }
            
            task.txt_priority = parse_priority (ref line);
            task.creation_date = parse_date (ref line);
            task.title = line;
            
            return task;
        }
        
        /**
         * If line contains a priority at the start of it, this removes the date 
         * from it and parses it.
         */
        private char parse_priority (ref string line) {
            if (line.length > 3) {
                if (line.get_char (0) == '(' && line.get_char (2) == ')' 
                        && line.get_char (3) == ' ') {
                    char priority = line.get (1);
                    
                    if (priority > 90 || priority < 65 )
                        return 0;
                    
                    priority = 26 + 65 - priority;
                    line = line.split (") ", 2)[1];
                    return priority;
                }
            }
            return 0;
        }
        
        /**
         * If line contains a date at the start of it, this removes the date 
         * from it and parses it.
         */
        private GLib.DateTime? parse_date (ref string line) {
            if (line.length > 10) {
                if (line.get_char (4) == '-' && 
                    line.get_char (7) == '-' && 
                    line.get_char (10) == ' '
                ) {
                    string[] temp = line.split_set ("- ", 4);
                    int year =  int.parse (temp[0]);
                    int month = int.parse (temp[1]);
                    int day = int.parse (temp[2]);
                    line = temp[3];
                    
                    GLib.DateTime date = new GLib.DateTime.local (
                        year, month, day, 0, 0, 0
                    );
                    
                    return date;
                }
            }
            return null;
        }
    }
}
