/* Copyright 2014-2019 GoForIt! developers
*
* This file is part of GoForIt!.
*
* GoForIt! is free software: you can redistribute it
* and/or modify it under the terms of version 3 of the
* GNU General Public License as published by the Free Software Foundation.
*
* GoForIt! is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with GoForIt!. If not, see http://www.gnu.org/licenses/.
*/

using GOFI.TXT.TxtUtils;

/**
 * This class is responsible for loading, saving and managing the user's tasks.
 * Therefore it offers methods for interacting with the set of tasks in all
 * lists. Editing specific tasks (e.g. removing, renaming) is to be done
 * by addressing the corresponding TaskStore instance.
 */
class GOFI.TXT.TaskManager : Object {
    private ListSettings lsettings;
    // The user's todo.txt related files
    private File todo_txt;
    private File done_txt;
    public TaskStore todo_store;
    public TaskStore done_store;
    private bool read_only;
    private bool io_failed;
    private bool single_file_mode;

    private TimeoutHandler timeout_handler;

    // refreshing
    private bool refresh_queued;
    private FileWatcher todo_watcher;
    private FileWatcher done_watcher;

    private uint todo_save_timeout_id;
    private uint done_save_timeout_id;

    private TxtTask active_task;
    private bool active_task_found;

    const string ERROR_IMPLICATIONS = _("%s won't save or load from the current todo.txt folder until it is either restarted or another location is chosen."); // vala-lint=line-length
    string read_error_message = _("Couldn't read the todo.txt file (%s):") + "\n\n%s\n\n";
    string write_error_message = _("Couldn't save the to-do list (%s):") + "\n\n%s\n\n";

    internal GLib.DateTime? static_date {
        get;
        set;
        default = null;
    }

    public bool new_tasks_on_top {
        get;
        set;
        default = false;
    }

    public signal void active_task_invalid ();
    public signal void refreshing ();
    public signal void refreshed ();

    public TaskManager (ListSettings lsettings) {
        this.lsettings = lsettings;

        // Initialize TaskStores
        todo_store = new TaskStore (false);
        done_store = new TaskStore (true);

        refresh_queued = false;
        todo_save_timeout_id = 0;
        done_save_timeout_id = 0;

        load_task_stores ();
        connect_store_signals ();

        timeout_handler = new TimeoutHandler (this);

        /* Signal processing */

        // these properties sometimes get updated multiple times without
        // actually changing, which could cause 1-6 extra reloads
        lsettings.notify["todo-uri"].connect (on_todo_uri_changed);
        lsettings.notify["done-uri"].connect (on_done_uri_changed);
    }

    internal TaskManager.test_instance () {
        this.lsettings = new ListSettings.empty ();

        // Initialize TaskStores
        todo_store = new TaskStore (false);
        done_store = new TaskStore (true);

        refresh_queued = false;
        todo_save_timeout_id = 0;
        done_save_timeout_id = 0;

        todo_txt = null;
        done_txt = null;
        read_only = true;

        connect_store_signals ();
    }

    /**
     * Using GLib.Timeout.add directly in the TaskManager will lead to a reference
     * count loop.
     */
    [Compact]
    private class TimeoutHandler {
        public unowned TaskManager task_manager;
        public uint job;

        public TimeoutHandler (TaskManager task_manager) {
            this.task_manager = task_manager;
            job = GLib.Timeout.add (300000, reschedule_overdue_tasks_job);
        }

        ~TimeoutHandler () {
            Source.remove (job);
        }

        public bool reschedule_overdue_tasks_job () {
            return task_manager.reschedule_overdue_tasks_job ();
        }
    }

    public void flush_changes_and_stop_monitoring () {
        lsettings.notify["todo-uri"].disconnect (on_todo_uri_changed);
        lsettings.notify["done-uri"].disconnect (on_done_uri_changed);
        save_queued_lists ();
        todo_watcher.watching = false;
        if (!single_file_mode) {
            done_watcher.watching = false;
        }
        todo_watcher = null;
        done_watcher = null;
        read_only = true;
    }

    private inline GLib.DateTime get_date () {
        if (static_date != null) {
            return static_date;
        }
        return new GLib.DateTime.now_local ();
    }

    private void on_todo_uri_changed () {
        if (lsettings.todo_uri != todo_txt.get_uri ()) {
            load_task_stores ();
        }
    }
    private void on_done_uri_changed () {
        if (lsettings.done_uri != done_txt.get_uri ()) {
            load_task_stores ();
        }
    }

    public void set_active_task (TxtTask? task) {
        active_task = task;
    }

    public TxtTask? get_next () {
        if (active_task == null) {
            return null;
        }
        return todo_store.get_task (
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
        return todo_store.get_task (
            active_pos - 1
        );
    }

    public void mark_done (TxtTask task) {
        // task.done = true;
        task.set_completed (new GOFI.Date (get_date ()));
    }

    /**
     * To be called when adding a new (unfinished) task.
     */
    public void add_new_task_from_txt (string task) {
        string _task = task.strip ();
        if (_task != "") {
            GOFI.Date? creation_date = lsettings.add_creation_dates ?
                new Date (get_date ()) : null;
            var todo_task = new TxtTask.from_simple_txt (_task, false, creation_date);
            if (!todo_task.valid) {
                return;
            }
            add_new_task (todo_task);
        }
    }

    public void add_new_tasks_from_strings (string[] task_strings) {
        for (int i = 0; i < task_strings.length; i++) {
            todo_store.add_task (new TxtTask (task_strings[i], false));
        }
    }

    public void add_new_task (TxtTask todo_task) {
        if (new_tasks_on_top) {
            todo_store.prepend_task (todo_task);
        } else {
            todo_store.add_task (todo_task);
        }
    }

    public TxtTask add_empty_task () {
        GOFI.Date? creation_date = lsettings.add_creation_dates ?
            new Date (get_date ()) : null;
        var todo_task = new TxtTask.from_simple_txt ("", false, creation_date);
        add_new_task (todo_task);
        return todo_task;
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
        load_and_reschedule_tasks ();
        refreshed ();
    }

    private bool auto_refresh () {
        if (todo_watcher.being_updated) {
            return true;
        }
        if (done_watcher != null && done_watcher.being_updated) {
            return true;
        }

        refresh ();

        refresh_queued = false;

        return false;
    }

    // I kept messing up comparisons
    private static inline bool date_before (GOFI.Date a, DateTime b) {
        return (a.dt_compare_date (b) < 0);
    }
    // private static inline bool date_after (GOFI.Date a, DateTime b) {
    //     return (a.dt_compare_date (b) > 0);
    // }

    private bool reschedule_overdue_tasks_job () {
        if (!refresh_queued) {
            reschedule_overdue_tasks ();
        }

        return Source.CONTINUE;
    }

    public void reschedule_overdue_tasks () {
        _reschedule_overdue_tasks (get_date ());
    }

    internal void _reschedule_overdue_tasks (DateTime now) {
        uint n_items = todo_store.get_n_items ();
        for (uint i = 0; i < n_items; i++) {
            var task = todo_store.get_task (i);
            task_auto_reschedule (now, task);
        }
    }

    private void task_auto_reschedule (DateTime now, TxtTask task) {
        if (task.recur_mode != RecurrenceMode.PERIODICALLY_AUTO_RESCHEDULE) {
            return;
        }
        Date? task_due = task.due_date;
        if (task_due != null && date_before (task_due, now)) {
            var due_dt = task_due.dt;
            unowned RecurrenceRule recur = task.recur;
            if (recur == null) {
                critical ("Invalid TxtTask state for task %p: recurrence rule is missing!", task);
                return;
            }
            var iter = new RecurrenceIterator (recur, due_dt);
            var new_due = iter.next_skip_dates (now);
            if (new_due != null) {
                task.due_date = new Date (new_due);
                unowned Date? threshold_date = task.threshold_date;
                if (threshold_date != null) {
                    task.threshold_date = new Date(threshold_date.dt.add (
                        new_due.difference (due_dt)
                    ));
                }
            }
        }
    }

    private void connect_store_signals () {
        // Save data, as soon as something has changed
        todo_store.task_data_changed.connect (queue_todo_task_save);
        done_store.task_data_changed.connect (queue_done_task_save);

        // Move task from one list to another, if done or undone
        todo_store.task_done_changed.connect (task_done_handler);
        done_store.task_done_changed.connect (task_done_handler);

        // Remove tasks that are no longer valid (user has changed description to "")
        todo_store.task_became_invalid.connect (remove_invalid);
        done_store.task_became_invalid.connect (remove_invalid);
    }

    private void load_task_stores () {
        todo_txt = File.new_for_uri (lsettings.todo_uri);
        done_txt = File.new_for_uri (lsettings.done_uri);

        single_file_mode = todo_txt.equal (done_txt);

        if (todo_txt.query_exists ()) {
            lsettings.add_default_todos = false;
        }

        load_and_reschedule_tasks ();

        if (!io_failed) {
            watch_files ();
        }
    }

    private void reschedule_completed_tasks () {
        var now = new DateTime.now_local ();
        uint n_items = done_store.get_n_items ();
        for (uint i = 0; i < n_items; i++) {
            TxtTask task = done_store.get_task (i);
            task_schedule_new (task, now);
        }
    }

    private void load_and_reschedule_tasks () {
        load_tasks ();
        reschedule_overdue_tasks ();
        reschedule_completed_tasks ();
    }

    private void watch_files () {
        todo_watcher = new FileWatcher (todo_txt);
        todo_watcher.changed.connect (on_file_changed);

        if (single_file_mode) {
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
    private void task_schedule_new (TxtTask task, DateTime? dt = null) {
        var recur_mode = task.recur_mode;

        if (recur_mode <= RecurrenceMode.NO_RECURRENCE) {
            return;
        }
        var new_task = new TxtTask.from_template_task (task);
        task.recur_mode = RecurrenceMode.NO_RECURRENCE;
        task.recur = null;

        DateTime? new_due_dt;
        DateTime now_dt;
        if (dt == null) {
            now_dt = get_date ();
        } else {
            now_dt = dt;
        }
        var due_date = new_task.due_date;
        var threshold_date = new_task.threshold_date;

        if (due_date == null) {
            if (threshold_date != null) {
                var threshold_dt = get_next_date (recur_mode, now_dt, new_task, threshold_date);
                if (threshold_dt == null) {
                    return;
                }
                threshold_date = new Date (threshold_dt);
            } else {
                due_date = new Date (get_date ());
            }
        }
        if (due_date != null) {
            new_due_dt = get_next_date (recur_mode, now_dt, new_task, due_date);
            var new_due_date = new Date (new_due_dt);
            new_task.due_date = new_due_date;
            if (new_due_dt == null) {
                return;
            }
            if (threshold_date != null) {
                var threshold_dt = threshold_date.dt.add_days (
                    due_date.days_between (new_due_date)
                );
                // if (due_date.)
                threshold_date = new Date (threshold_dt);
            }
        }
        if (threshold_date != null) {
            new_task.threshold_date = threshold_date;
            // if (date_after (threshold_date, now_dt)) {
            //     waiting_store.add_task (new_task);
            //     return;
            // }
        }
        if (lsettings.add_creation_dates) {
            new_task.creation_date = new Date (get_date ());
        }
        add_new_task (new_task);
    }

    private GLib.DateTime? get_next_date (RecurrenceMode recur_mode, DateTime now_dt, TxtTask task, GOFI.Date date) {
        unowned RecurrenceRule recur = task.recur;
        if (recur == null) {
            critical ("Invalid TxtTask state for task %p: recurrence rule is missing!", task);
            return null;
        }
        DateTime? next_date;
        switch (recur_mode) {
            case RecurrenceMode.PERIODICALLY_AUTO_RESCHEDULE:
            case RecurrenceMode.PERIODICALLY_SKIP_OLD:
                var iter = new RecurrenceIterator (recur, date.dt);
                next_date = iter.next_skip_dates (now_dt);
                break;
            case RecurrenceMode.ON_COMPLETION:
                unowned DateTime completion_date;
                if (task.completion_date != null) {
                    completion_date = task.completion_date.dt;
                } else {
                    completion_date = now_dt;
                }
                var iter = new RecurrenceIterator (recur, completion_date);
                next_date = iter.next ();
                break;
            default:
                var iter = new RecurrenceIterator (recur, date.dt);
                next_date = iter.next ();
                break;
        }

        return next_date;
    }

    private void task_done_handler (TaskStore source, TxtTask task) {
        if (source == todo_store) {
            transfer_task (task, todo_store, done_store);
            if (task == active_task) {
                active_task_invalid ();
            }
            task_schedule_new (task);
        } else if (source == done_store) {
            transfer_task (task, done_store, todo_store);
        } else {
            assert_not_reached ();
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
        done_store.clear ();
        active_task_found = active_task == null;
        read_task_file (this.todo_txt, false);
        if (!single_file_mode) {
            read_task_file (this.done_txt, true);
        }

        read_only = false;

        if (!active_task_found) {
            active_task_invalid ();
        }
    }

    /**
     * Saves lists for which a timeout job exists
     */
    public void save_queued_lists () {
        if (todo_save_timeout_id != 0) {
            Source.remove (todo_save_timeout_id);
            save_todo_tasks ();
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

    private void queue_done_task_save () {
        if (done_save_timeout_id != 0 || read_only) {
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
        bool is_todo_store = store == todo_store;
        File todo_file = is_todo_store ? todo_txt : done_txt;
        if (single_file_mode) {
            todo_watcher.watching = false;
            write_task_file ({todo_store, done_store}, todo_file);
            todo_watcher.watching = true;
        } else {
            FileWatcher watcher = is_todo_store ? todo_watcher : done_watcher;
            watcher.watching = false;
            write_task_file ({store}, todo_file);
            watcher.watching = true;
        }
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

        // Read data from todo.txt and done.txt files
        try {
            ensure_file_exists (file);
            var stream_in = new DataInputStream (file.read ());
            string line;

            while ((line = stream_in.read_line (null)) != null) {
                TxtTask? task = string_to_task (line, done_by_default);
                if (task != null) {
                    if (task.done) {
                        done_store.add_task (task);
                    } else {
                        todo_store.add_task (task);
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

        var bytes = stores_to_bytes (stores);
        var to_write = bytes.get_size ();
        try {
            ensure_file_exists (file);
            var file_out_stream =
                file.replace (null, true, FileCreateFlags.NONE);
            var written = file_out_stream.write_bytes (bytes);
            while (written < to_write) {
                written += file_out_stream.write_bytes (
                    new Bytes.from_bytes (bytes, written, to_write - written)
                );
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

    /**
     * Appends the tasks formatted as todo.txt tasks to a StringBuilder.
     * Every task is terminated with a newline
     */
    private void write_tasks_to_builder (TaskStore store, StringBuilder str_builder, bool log_timer) {
        uint n_items = store.get_n_items ();
        for (uint i = 0; i < n_items; i++) {
            var task = store.get_task (i);
            if (task.valid) {
                store.get_task (i).append_txt_to_builder (str_builder, log_timer);
                str_builder.append_c ('\n');
            }
        }
    }

    private Bytes stores_to_bytes (TaskStore[] stores) {
        uint initial_buffer_size = 0;

        foreach (var store in stores) {
            initial_buffer_size += store.get_n_items () * 64;
        }

        var str_builder = new StringBuilder.sized (initial_buffer_size);
        bool log_timer = lsettings.log_timer_in_txt;
        foreach (var store in stores) {
            write_tasks_to_builder (store, str_builder, log_timer);
        }

        return StringBuilder.free_to_bytes ((owned) str_builder);
    }
}
