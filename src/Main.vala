/* Copyright 2014-2017 Go For It! developers
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

/**
 * The main application class that is responsible for initiating all
 * necessary steps to create a running instance of "Go For It!".
 */
class Main : Gtk.Application {
    private SettingsManager settings;
    private TaskManager task_manager;
    private TaskTimer task_timer;
    private MainWindow win;
    private string? todo_txt_location = null;

    /**
     * Constructor of the Application class.
     */
    public Main (string? application_id, string? todo_txt_location, ApplicationFlags flags) {
        string? location_path = null;
        string? location_id = null;
        string? app_id = null;
        SettingsManager settings;

        settings = new SettingsManager.load_from_key_file ();
        location_path = Posix.realpath (todo_txt_location != null ? todo_txt_location : settings.todo_txt_location);

        /* NOTE: encoding file paths into application ID leads to side effect, when
         * several paths form same id content, e.g. "/foo.bar" & "/foo_bar"
         * (forced due to restricted character set, allowed in app ID string)
         ****************/
        location_id = location_path;
        location_id._delimit (".", '_');
        location_id._delimit ("/", '.');
        app_id = application_id + location_id;

        /* finally, constructing */
        Object (application_id: app_id, flags: flags);
        this.settings = settings;
        this.todo_txt_location = location_path;
    }

    public void new_window () {
        // Don't create a new window, if one already exists
        if (win != null) {
            win.show ();
            win.present ();
            return;
        }

        task_manager = new TaskManager(settings, todo_txt_location);
        task_timer = new TaskTimer (settings);
        task_timer.active_task_done.connect ( (task) => {
             task_manager.mark_task_done (task);
        });

        win = new MainWindow (this, task_manager, task_timer, settings);
        win.show_all ();
    }

    public void show_about (Gtk.Window? parent = null) {
        var dialog = new AboutDialog (parent);
        dialog.run ();
    }

    public override int command_line (ApplicationCommandLine command_line) {
        hold ();
        int res = _command_line (command_line);
        release ();
        return res;
    }

    private int _command_line (ApplicationCommandLine command_line) {
        new_window ();
        return 0;
    }
}


