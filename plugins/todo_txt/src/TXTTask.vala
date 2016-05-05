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
    public class TXTTask : GOFI.TodoTask {
        
        public GLib.DateTime? creation_date = null;
        public GLib.DateTime? completion_date = null;
        public char txt_priority;
        
        private string _title;
        
        public TXTTask () {
            base ();
            txt_priority = 0;
        }
        
        /**
         * Parses a single line from the todo.txt file.
         */
        public TXTTask.from_txt (string todo_line) {
            set_txt (todo_line);
        }
        
        public void set_txt (string todo_line) {
            string line = todo_line;
            
            // Todo.txt notation: completed tasks start with an "x "
            done = line.has_prefix ("x ");
                
            if (done) {
                // Remove "x " from displayed string
                line = line.split ("x ", 2)[1];
                completion_date = parse_date (ref line);
            }
            
            txt_priority = parse_priority (ref line);
            creation_date = parse_date (ref line);
            _title = line;
            title = priority_to_string (txt_priority) + _title;
        }
        
        public bool equals (TXTTask other_task) {
            return this.title == other_task.title;
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
        
        public override void status_changed (bool done) {
            if (done) {
                completion_date = new GLib.DateTime.now_local ();
            } else {
                completion_date = null;
            }
            
            base.status_changed (done);
        }
        
        public string to_txt () {
            string creation_str = date_to_string(creation_date);
            string done_str, completion_str, priority_str;
            
            if (done) {
                completion_str = date_to_string(completion_date);
                done_str = "x ";
                priority_str = ""; 
            }
            else {
                completion_str = "";
                done_str = ""; 
                priority_str = priority_to_string (txt_priority);
            }
            
            string pre = done_str + completion_str + priority_str + creation_str;
            
            return pre + _title;
        }

        private string date_to_string (GLib.DateTime? date) {
            if (date == null) {
                return "";
            }
            
            return date.format ("%Y-%m-%d ");
        }

        /*
         * TODO: check if this is correct ...
         */
        private string priority_to_string (char priority) {
            if (priority < 1 || priority > 26) {
                return "";
            }
            
            GLib.StringBuilder builder = new GLib.StringBuilder ("(");
            builder.append_c (26 - priority + 65);
            builder.append (") ");
            
            return builder.str;
        }
    }
}
