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
     * ...
     */
    class Filter {
        private Gee.List<string> literal;
        private Gee.List<string> words;
        
        public signal void changed ();
        
        public Filter () {
            literal = new Gee.LinkedList<string> ();
            words = new Gee.LinkedList<string> ();
        }
        
        public void parse (string search_string) {
            literal.clear ();
            words.clear ();
            
            if (search_string == "") {
                changed ();
                return;
            }
            
            string[] parts = search_string.split(" ");
            
            foreach (string part in parts) {
                if (part == "") {
                    continue;
                }
                if (part.has_prefix("project:")) {
                    string? project = part.split(":", 2)[1];
                    if (project != null && project != "") {
                        literal.add("+" + project);
                    }
                } else if (part.has_prefix("context:")) {
                    string? context = part.split(":", 2)[1];
                    if (context != null && context != "") {
                        literal.add("@" + context);
                    }
                } else {
                    words.add(part.casefold ());
                }
            }
            
            changed ();
        }
        
        /**
         * Checks if search_string is a substring with the following extra 
         * properties: if title doesn't start with search_string a space must 
         * preceed it, and if title doesn't end with it a space must succeed it.
         */
        private bool contains_literal (string title, string search_string) {
            int index, title_length, search_length;
            
            index = title.index_of (search_string);
            
            if (index >= 0) {
                if (index > 0) {
                    if (title.get(index - 1) != ' ') {
                        return false;
                    }
                }
                title_length = title.length;
                search_length = search_string.length;
                if (index + search_length < title_length) {
                    return (title.get (index + search_length) == ' ');
                }
                return true;
            }
            return false;
        }
        
        public bool filter (OrderBoxRow row) {
            var _row = row as TaskRow;
            
            foreach (string literal_word in literal) {
                if (!contains_literal (_row.task.title, literal_word )) {
                    return false;
                }
            }
            
            string title = _row.task.title.casefold ();
            
            foreach (string word in words) {
                if (!title.contains (word)) {
                    return false;
                }
            }
            
            return true;
        }
    }
}
