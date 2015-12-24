/* Copyright 2014 Manuel Kehl (mank319)
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
     * A dialog for changing the application's settings.
     */
    public class SettingsWidget : Gtk.Grid {
        private SettingsManager settings;
        /* GTK Widgets */
        private Gtk.Label directory_lbl;
        private Gtk.Label directory_explanation_lbl;
        private Gtk.FileChooserButton directory_btn;
        
        public SettingsWidget (SettingsManager settings) {
            this.settings = settings;
            
            /* General Settigns */
            this.visible = true;
            this.orientation = Gtk.Orientation.VERTICAL;
            this.row_spacing = 15;
            
            setup_settings_widgets (true);
            
            /* Settings that apply for all widgets in the dialog */
            foreach (var child in this.get_children ()) {
                child.visible = true;
                child.halign = Gtk.Align.START;
            }
        }
        
        private void setup_settings_widgets (bool advanced) {
            /* Instantiation */
            directory_btn = new Gtk.FileChooserButton ("Todo.txt " + _("directory"),
                Gtk.FileChooserAction.SELECT_FOLDER);
                
            directory_lbl = new Gtk.Label (
                "<a href=\"http://todotxt.com\">Todo.txt</a> "
                + _("directory") + ":"
            );
                
            directory_explanation_lbl = new Gtk.Label (
                _("If no appropriate folder was found, Go For It! defaults to creating a Todo folder in your home directory.")
            );
            
            /* Configuration */
            directory_lbl.set_line_wrap (false);
            directory_lbl.set_use_markup (true);
            directory_explanation_lbl.set_line_wrap (true);
            directory_btn.create_folders = true;
            directory_btn.set_current_folder (settings.todo_txt_location);
            
            /* Signal Handling */
            directory_btn.file_set.connect ((e) => {
                var todo_dir = directory_btn.get_file ().get_path ();
                settings.todo_txt_location = todo_dir;
            });
            
            /* Add widgets */
            this.add (directory_lbl);
            this.add (directory_explanation_lbl);
            this.add (directory_btn);
        }
    }
}
