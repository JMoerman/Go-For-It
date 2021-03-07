/* Copyright 2014-2019 Go For It! developers
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

using GOFI.TXT.TxtUtils;

/**
 * This class is responsible for loading, saving and managing the user's tasks.
 * Therefore it offers methods for interacting with the set of tasks in all
 * lists. Editing specific tasks (e.g. removing, renaming) is to be done
 * by addressing the corresponding TaskStore instance.
 */
class GOFI.TXT.TaskManager {
    private ListSettings lsettings;
    // The user's todo.txt related files
    private File todo_txt;
    private File done_txt;
    private File waiting_txt;
    public TaskStore todo_store;
    public TaskStore done_store;
    public TaskStore waiting_store;
    private bool read_only;
    private bool io_failed;

    // refreshing
    private bool refresh_queued;
    private FileWatcher todo_watcher;
    private FileWatcher done_watcher;
    private FileWatcher waiting_watcher;

    private uint todo_save_timeout_id;
    private uint done_save_timeout_id;
    private uint waiting_save_timeout_id;

    private TxtTask active_task;
    private bool active_task_found;

    const string ERROR_IMPLICATIONS = _("%s won't save or load from the current todo.txt folder until it is either restarted or another location is chosen."); // vala-lint=line-length
    string read_error_message = _("Couldn't read the todo.txt file (%s):") + "\n\n%s\n\n";
    string write_error_message = _("Couldn't save the to-do list (%s):") + "\n\n%s\n\n";

    public signal void active_task_invalid ();
    public signal void refreshing ();
    public signal void refreshed ();

    public TaskManager (ListSettings lsettings) {
        this.lsettings = lsettings;

        // Initialize TaskStores
        todo_store = new TaskStore (false);
        waiting_store = new TaskStore (false);
        done_store = new TaskStore (true);

        refresh_queued = false;
        todo_save_timeout_id = 0;
        done_save_timeout_id = 0;
        waiting_save_timeout_id = 0;

        load_task_stores ();
        connect_store_signals ();
        post_load_task_schedule ();

        GLib.Timeout.add (300000, move_waiting_tasks);
        GLib.Timeout.add (300000, reschedule_overdue_tasks);

        /* Signal processing */

        // these properties sometimes get updated multiple times without
        // actually changing, which could cause 1-6 extra reloads
        lsettings.notify["todo-uri"].connect (on_todo_uri_changed);
        lsettings.notify["waiting-uri"].connect (on_waiting_uri_changed);
        lsettings.notify["done-uri"].connect (on_done_uri_changed);
    }

    public void prepare_free () {
        lsettings.notify["todo-uri"].disconnect (on_todo_uri_changed);
        lsettings.notify["waiting-uri"].disconnect (on_waiting_uri_changed);
        lsettings.notify["done-uri"].disconnect (on_done_uri_changed);
    }

    private void on_todo_uri_changed () {
        if (lsettings.todo_uri != todo_txt.get_uri ()) {
            load_tasks_stores_and_reschedule ();
        }
    }
    private void on_waiting_uri_changed () {
        if (lsettings.waiting_uri != waiting_txt.get_uri ()) {
            load_tasks_stores_and_reschedule ();
        }
    }
    private void on_done_uri_changed () {
        if (lsettings.done_uri != done_txt.get_uri ()) {
            load_tasks_stores_and_reschedule ();
        }
    }

    public void set_active_task (TxtTask? task) {
        active_task = task;
    }

    public TxtTask? get_next () {
        if (active_task == null) {
            return null;
        }
        return (TxtTask) todo_store.get_item (
            todo_store.get_task_position (active_task) + 1
        );
    }

    public TxtTask? get_prev () {
        if (active_task == null) {
            return null;
        }
        var active_pos = todo_store.get_task_position (active_task);
        if (active_pos == 0) {
            return active_task;
        }
        return (TxtTask) todo_store.get_item (
            active_pos - 1
        );
    }

    public void mark_done (TxtTask task) {
        task.done = true;
    }

    /**
     * To be called when adding a new (unfinished) task.
     */
    public void add_new_task (string task) {
        string _task = task.strip ();
        if (_task != "") {
            var todo_task = new TxtTask.from_simple_txt (_task, false);
            if (!todo_task.valid) {
                return;
            }
            if (!lsettings.add_creation_dates) {
                todo_task.creation_date = null;
            }
            if (settings.new_tasks_on_top) {
                todo_store.prepend_task (todo_task);
            } else {
                todo_store.add_task (todo_task);
            }
        }
    }

    /**
     * Transfers a task from one TaskStore to another.
     */
    private void transfer_task (
        TxtTask task, TaskStore source, TaskStore destination
    ) {
        source.remove_task (task);
        destination.add_task (task);
    }

    /**
     * Deletes all task on the "Done" list
     */
    public void clear_done_store () {
        done_store.clear ();
    }

    public void sort_tasks () {
        todo_store.sort ();
        done_store.sort ();
    }

    /**
     * Reloads all tasks.
     */
    public void refresh () {
        stdout.printf ("Refreshing\n");
        refreshing ();
        load_tasks ();
        post_load_task_schedule ();
        refreshed ();
    }

    private bool auto_refresh () {
        // Have the writes stopped yet?
        if (todo_watcher.being_updated) {
            return true;
        }
        if ((done_watcher != null && done_watcher.being_updated) ||
            (waiting_watcher != null && waiting_watcher.being_updated)
        ) {
            return true;
        }

        refresh ();

        refresh_queued = false;

        return false;
    }

    private bool move_waiting_tasks () {
        if (!refresh_queued) {
            var now = new DateTime.now_local ();
            uint n_items = waiting_store.get_n_items ();
            (unowned TxtTask)[] to_move = {};
            for (uint i = 0; i < n_items; i++) {
                unowned TxtTask task = (TxtTask) waiting_store.get_item (i);
                if (task.threshold_date.compare (now) >= 0) {
                    to_move += task;
                }
            }
            foreach (unowned TxtTask task in to_move) {
                transfer_task (task, waiting_store, todo_store);
            }
        }

        return Source.CONTINUE;
    }

    private bool reschedule_overdue_tasks () {
        if (!refresh_queued) {
            var now = new DateTime.now_local ();
            uint n_items = todo_store.get_n_items ();
            for (uint i = 0; i < n_items; i++) {
                unowned TxtTask task = (TxtTask) todo_store.get_item (i);
                task_auto_reschedule (now, task);
            }
        }

        return Source.CONTINUE;
    }

    private void task_auto_reschedule (DateTime now, TxtTask task) {
        if (task.recur_mode != RecurrenceMode.PERIODICALLY_AUTO_RESCHEDULE) {
            return;
        }
        DateTime? task_due = task.due_date;
        if (task_due != null && task_due.compare (now) < 0) {
            unowned SimpleRecurrence recur = task.recur;
            if (recur == null) {
                critical ("Invalid TxtTask state for task %p: recurrence rule is missing!", task);
                return;
            }
            var iter = new SimpleRecurrenceIterator (recur, task_due);
            var new_due = iter.next_skip_dates (now);
            if (new_due != null) {
                task.due_date = new_due;
                unowned DateTime? threshold_date = task.threshold_date;
                if (threshold_date != null) {
                    task.threshold_date = threshold_date.add (
                        new_due.difference (task_due)
                    );
                }
            }
        }
    }

    private void connect_store_signals () {
        // Save data, as soon as something has changed
        todo_store.task_data_changed.connect (queue_todo_task_save);
        waiting_store.task_data_changed.connect (queue_waiting_task_save);
        done_store.task_data_changed.connect (queue_done_task_save);

        // Move task from one list to another, if done or undone
        todo_store.task_done_changed.connect (task_done_handler);
        waiting_store.task_done_changed.connect (task_done_handler);
        done_store.task_done_changed.connect (task_done_handler);

        todo_store.task_threshold_date_changed.connect (ready_task_threshold_date_changed);
        waiting_store.task_threshold_date_changed.connect (waiting_task_threshold_date_changed);

        // Remove tasks that are no longer valid (user has changed description to "")
        todo_store.task_became_invalid.connect (remove_invalid);
        waiting_store.task_became_invalid.connect (remove_invalid);
        done_store.task_became_invalid.connect (remove_invalid);
    }

    private void ready_task_threshold_date_changed (TxtTask task) {
        var now = new DateTime.now_local ();
        if (task.threshold_date.compare (now) < 0) {
            transfer_task (task, todo_store, waiting_store);
        }
    }

    private void waiting_task_threshold_date_changed (TxtTask task) {
        var now = new DateTime.now_local ();
        if (task.threshold_date.compare (now) >= 0) {
            transfer_task (task, waiting_store, todo_store);
        }
    }

    private void load_task_stores () {
        todo_txt = File.new_for_uri (lsettings.todo_uri);
        done_txt = File.new_for_uri (lsettings.done_uri);
        waiting_txt = File.new_for_uri (lsettings.waiting_uri);

        if (todo_txt.query_exists ()) {
            lsettings.add_default_todos = false;
        }

        load_tasks ();

        if (!io_failed) {
            watch_files ();
        }
    }

    private void watch_files () {
        todo_watcher = new FileWatcher (todo_txt);
        todo_watcher.changed.connect (on_file_changed);

        if (todo_txt.equal (waiting_txt)) {
            waiting_watcher = null;
        } else {
            waiting_watcher = new FileWatcher (waiting_txt);
            waiting_watcher.changed.connect (on_file_changed);
        }
        if (todo_txt.equal (done_txt) || waiting_txt.equal (done_txt)) {
            done_watcher = null;
        } else {
            done_watcher = new FileWatcher (done_txt);
            done_watcher.changed.connect (on_file_changed);
        }
    }

    private void on_file_changed () {
        if (!refresh_queued) {
            refresh_queued = true;

            // Reload after 0.5 seconds so we can be relatively sure, that the
            // other application has finished writing
            GLib.Timeout.add (
                500, auto_refresh, GLib.Priority.DEFAULT_IDLE
            );
        }
    }

    /**
     * Removes recurrence information from task and schedules new task if
     * necessary
     */
    private void task_schedule_new (TxtTask task, DateTime? date = null) {
        var recur_mode = task.recur_mode;

        if (recur_mode <= RecurrenceMode.NO_RECURRENCE) {
            return;
        }
        unowned SimpleRecurrence recur = task.recur;
        if (recur == null) {
            critical ("Invalid TxtTask state for task %p: recurrence rule is missing!", task);
            return;
        }
        var new_task = new TxtTask.from_template_task (task);
        task.recur_mode = RecurrenceMode.NO_RECURRENCE;
        task.recur = null;
        var task_due = new_task.due_date;
        if (task_due == null) {
            warning ("Encountered recurring todo.txt task without due date: %s", task.to_txt (false));
            task_due = new GLib.DateTime.now_local ();
        }
        DateTime new_due;
        DateTime now_date;
        if (date == null) {
            now_date = new DateTime.now_local ();
        } else {
            now_date = date;
        }
        switch (recur_mode) {
            case RecurrenceMode.PERIODICALLY_AUTO_RESCHEDULE:
            case RecurrenceMode.PERIODICALLY_SKIP_OLD:
                var iter = new SimpleRecurrenceIterator (recur, task_due);
                new_due = iter.next_skip_dates (now_date);
                break;
            case RecurrenceMode.ON_COMPLETION:
                unowned DateTime completion_date = task.completion_date;
                if (completion_date == null) {
                    completion_date = now_date;
                }
                var iter = new SimpleRecurrenceIterator (recur, completion_date);
                new_due = iter.next ();
                int year, month, day;
                new_due.get_ymd (out year, out month, out day);
                new_due = new DateTime.local (year, month, day, 23, 59, 59.0);
                break;
            default:
                var iter = new SimpleRecurrenceIterator (recur, task_due);
                new_due = iter.next ();
                break;
        }
        if (new_due == null) {
            return;
        }
        if (lsettings.add_creation_dates) {
            new_task.creation_date = new GLib.DateTime.now_local ();
        }
        new_task.due_date = new_due;
        if (task.threshold_date != null) {
            new_task.threshold_date = new_task.threshold_date.add (
                new_due.difference (task_due)
            );
            if (new_task.threshold_date.compare (now_date) >= 0) {
                waiting_store.add_task (new_task);
                return;
            }
        }
        todo_store.add_task (new_task);
    }

    private void task_done_handler (TaskStore source, TxtTask task) {
        if (source == todo_store) {
            transfer_task (task, todo_store, done_store);
            task_schedule_new (task);
            if (task == active_task) {
                active_task_invalid ();
            }
        } else if (source == done_store) {
            transfer_task (task, done_store, todo_store);
        } else if (source == waiting_store) {
            transfer_task (task, waiting_store, done_store);
            task_schedule_new (task);
        }
    }

    private void remove_invalid (TaskStore store, TxtTask task) {
        store.remove_task (task);
        save_store (store);
    }

    private void load_tasks () {
        // read_only flag, so that "clear ()" does not delete the files' content
        read_only = true;
        todo_store.clear ();
        waiting_store.clear ();
        done_store.clear ();
        active_task_found = active_task == null;
        read_task_file (todo_txt, false);

        if (!todo_txt.equal (waiting_txt)) {
            read_task_file (waiting_txt, false);
        }
        if (!(todo_txt.equal (done_txt) || waiting_txt.equal (done_txt))) {
            read_task_file (done_txt, true);
        }

        if (settings.add_default_todos && lsettings.add_default_todos) {
            add_default_todos ();
        }

        read_only = false;

        if (!active_task_found) {
            active_task_invalid ();
        }
    }

    private void post_load_task_schedule () {
        var now = new DateTime.now_local ();
        uint n_items = done_store.get_n_items ();
        for (uint i = 0; i < n_items; i++) {
            unowned TxtTask task = (TxtTask) done_store.get_item (i);
            task_schedule_new (task, now);
        }
    }

    private void load_tasks_stores_and_reschedule () {
        load_task_stores ();
        post_load_task_schedule ();
    }

    private void add_default_todos () {
        var default_todos = get_default_todos ();
        for (int i = 0; i < default_todos.length; i++) {
            todo_store.add_task (new TxtTask (default_todos[i], false));
        }
        lsettings.add_default_todos = false;
        settings.add_default_todos = false;
    }

    /**
     * Saves lists for which a timeout job exists
     */
    public void save_queued_lists () {
        if (todo_save_timeout_id != 0) {
            Source.remove (todo_save_timeout_id);
            save_todo_tasks ();
        }
        if (waiting_save_timeout_id != 0) {
            Source.remove (waiting_save_timeout_id);
            save_waiting_tasks ();
        }
        if (done_save_timeout_id != 0) {
            Source.remove (done_save_timeout_id);
            save_done_tasks ();
        }
    }

    /**
     * Adds a timeout job to save the todo.txt list.
     * A timeout is used to reduce the number of times the list is saved.
     * It may be useful to increase the interval value to reduce the amount of
     * stutter when dealing with very large lists on weak machines.
     * (Move the moment of saving to a time where the user isn't actively
     * using the app)
     * But we would need to check that the user isn't currently performing a
     * drag and drop action as saves at such a moment would be the most
     * noticable.
     */
    private void queue_todo_task_save () {
        if (todo_save_timeout_id != 0 || read_only) {
            return;
        }
        todo_save_timeout_id = GLib.Timeout.add (
            100, save_todo_tasks, GLib.Priority.DEFAULT_IDLE
        );
    }

    private void queue_waiting_task_save () {
        if (waiting_save_timeout_id != 0 || read_only) {
            return;
        }
        if (todo_txt.equal (waiting_txt)) {
            queue_todo_task_save ();
            return;
        }
        waiting_save_timeout_id = GLib.Timeout.add (
            100, save_waiting_tasks, GLib.Priority.DEFAULT_IDLE
        );
    }

    private void queue_done_task_save () {
        if (done_save_timeout_id != 0 || read_only) {
            return;
        }
        if (waiting_txt.equal (done_txt)) {
            queue_waiting_task_save ();
            return;
        }
        if (todo_txt.equal (done_txt)) {
            queue_todo_task_save ();
            return;
        }
        done_save_timeout_id = GLib.Timeout.add (
            100, save_done_tasks, GLib.Priority.DEFAULT_IDLE
        );
    }

    private bool save_todo_tasks () {
        if (!read_only) {
            save_store (todo_store);
        }
        todo_save_timeout_id = 0;
        return false;
    }

    private bool save_waiting_tasks () {
        if (!read_only) {
            save_store (waiting_store);
        }
        waiting_save_timeout_id = 0;
        return false;
    }

    private bool save_done_tasks () {
        if (!read_only) {
            save_store (done_store);
        }
        done_save_timeout_id = 0;
        return false;
    }

    private void show_error_dialog (string error_message) {
        var dialog = new Gtk.MessageDialog (
            null, Gtk.DialogFlags.DESTROY_WITH_PARENT, Gtk.MessageType.ERROR,
            Gtk.ButtonsType.OK, error_message
        );
        dialog.response.connect ((response_id) => {
            dialog.destroy ();
        });

        dialog.show ();
    }

    private void save_store (TaskStore store) {
        File todo_file;
        FileWatcher watcher = null;
        TaskStore[] stores = {};

        if (store == todo_store) {
            todo_file = todo_txt;
            watcher = todo_watcher;

            if (todo_txt.equal (waiting_txt)) {
                stores = {todo_store, waiting_store};
            } else {
                stores = {todo_store};
            }
            if (todo_txt.equal (done_txt)) {
                stores += done_store;
            }
        } else if (store == done_store) {
            todo_file = done_txt;
            if (done_txt.equal (todo_txt)) {
                stores = {todo_store};
                watcher = todo_watcher;
            }
            if (done_txt.equal (waiting_txt)) {
                stores += waiting_store;
                if (watcher == null) {
                    watcher = waiting_watcher;
                }
            } else if (watcher == null) {
                watcher = done_watcher;
            }
            stores += done_store;
        } else {
            todo_file = waiting_txt;
            if (waiting_txt.equal (todo_txt)) {
                stores = {todo_store, waiting_store};
                watcher = todo_watcher;
            } else {
                stores = {waiting_store};
                watcher = waiting_watcher;
            }
            if (waiting_txt.equal (done_txt)) {
                stores += done_store;
            }
        }
        watcher.watching = false;
        write_task_file (stores, todo_file);
        watcher.watching = true;
    }

    // Create file with its parent directory if it doesn't currently exist
    private void ensure_file_exists (File file) throws Error {
        Utils.ensure_file_exists (file, FileCreateFlags.NONE);
    }

    string remove_carriage_return (string line) {
        int length = line.length;
        if (length > 0) {
            if (line.get_char (length - 1) == 13) {
                if (length == 1) {
                    return "";
                }
                return line.slice (0, length - 1);
            }
        }

        return line;
    }

    private TxtTask? string_to_task (string _line, bool done_by_default) {
        string line = remove_carriage_return (_line).strip ();
        if (line == "") {
            return null;
        }
        var task = new TxtTask.from_todo_txt (line, done_by_default);
        if (!task.valid) {
            return null;
        }

        if (!active_task_found && !task.done) {
            if (task.description == active_task.description) {
                active_task_found = true;
                return active_task;
            }
        }

        return task;
    }

    /**
     * Reads tasks from a Todo.txt formatted file.
     */
    private void read_task_file (File file, bool done_by_default) {
        if (io_failed) {
            return;
        }
        message ("Reading todo.txt file: %s\n", file.get_uri ());
        var now_time = new DateTime.now_local ();

        // Read data from todo.txt and done.txt files
        try {
            ensure_file_exists (file);
            var stream_in = new DataInputStream (file.read ());
            string line;

            var now = new DateTime.now_local ();

            while ((line = stream_in.read_line (null)) != null) {
                TxtTask? task = string_to_task (line, done_by_default);

                if (task != null) {
                    if (task.done) {
                        done_store.add_task (task);
                    } else {
                        task_auto_reschedule (now, task);
                        if (task.threshold_date != null &&
                            task.threshold_date.compare (now_time) >= 0
                        ) {
                            waiting_store.add_task (task);
                        } else {
                            todo_store.add_task (task);
                        }
                    }
                }
            }
        } catch (Error e) {
            io_failed = true;
            var error_message =
                read_error_message.printf (file.get_uri (), e.message) +
                ERROR_IMPLICATIONS.printf (APP_NAME);
            warning (error_message);
            show_error_dialog (error_message);
        }
    }

    /**
     * Saves tasks to a Todo.txt formatted file.
     */
    private void write_task_file (TaskStore[] stores, File file) {
        if (io_failed) {
            return;
        }
        message ("Writing todo.txt file: %s\n", file.get_uri ());

        try {
            ensure_file_exists (file);
            var file_out_stream =
                file.replace (null, true, FileCreateFlags.NONE);
            var stream_out =
                new DataOutputStream (file_out_stream);

            foreach (var store in stores) {
                write_tasks_to_stream (store, stream_out, lsettings.log_timer_in_txt);
            }
        } catch (Error e) {
            io_failed = true;
            var error_message =
                write_error_message.printf (file.get_uri (), e.message) +
                ERROR_IMPLICATIONS.printf (APP_NAME);
            warning (error_message);
            show_error_dialog (error_message);
        }
    }

    private void write_tasks_to_stream (TaskStore store, DataOutputStream stream_out, bool log_timer) throws Error {
        uint n_items = store.get_n_items ();
        for (uint i = 0; i < n_items; i++) {
            TxtTask task = (TxtTask)store.get_item (i);
            stream_out.put_string (task.to_txt (log_timer));
            stream_out.put_byte ('\n');
        }
    }
}
