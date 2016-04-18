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
     * A class for writing tasks to a .txt file.
     */
    class Writer : Object {
        
        /**
         * @param tasks list of tasks that needs to be written to a todo.txt
         * file.
         */
        public void write (File file, Gee.List<TXTTask> tasks) {
            try {
                var file_io_stream = 
                    file.replace_readwrite (null, true, FileCreateFlags.NONE);
                var stream_out = 
                    new DataOutputStream (file_io_stream.output_stream);
                
                foreach (TXTTask task in tasks) {
                    stream_out.put_string (task_to_txt (task) + "\n");
                }
            } catch (Error e) {
                error ("%s", e.message);
            }
        }
        
        private string task_to_txt (TXTTask task) {
            string title = task.title;
            string creation_date = date_to_string(task.creation_date);
            string done, completion_date, priority;
            
            if (task.done) {
                completion_date = date_to_string(task.completion_date);
                done = "x ";
                priority = ""; 
            }
            else {
                completion_date = "";
                done = ""; 
                priority = priority_to_string (task.txt_priority);
            }
            
            string pre = done + completion_date + priority + creation_date;
            
            return pre + title;
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
